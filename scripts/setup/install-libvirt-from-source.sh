#!/usr/bin/env bash
set -euo pipefail

# install-libvirt-from-source.sh
# Installs libvirt from source on Debian/Ubuntu style systems.
#
# Usage:
#   ./install-libvirt-from-source.sh [options]
#
# Example:
#   ./install-libvirt-from-source.sh \
#     --repo-url https://gitlab.com/libvirt/libvirt.git \
#     --source-dir ./build/libvirt-src \
#     --build-type debug \
#     --purge-distro-libvirt \
#     --yes

REPO_URL="https://gitlab.com/libvirt/libvirt.git"
SOURCE_DIR="${PWD}/build/libvirt-src"
BUILD_TYPE="release"
PURGE_DISTRO_LIBVIRT=false
SKIP_SERVICE_CONFIG=false
ASSUME_YES=false

usage() {
    cat <<'EOF'
Usage:
  install-libvirt-from-source.sh [options]

Options:
      --repo-url <url>               Git repository URL (default: https://gitlab.com/libvirt/libvirt.git)
      --source-dir <path>            Source checkout directory (default: ./build/libvirt-src)
      --build-type <debug|release>   Meson build type (default: release)
      --purge-distro-libvirt         Remove distro libvirt packages first
      --skip-service-config          Skip systemctl/usermod post-install actions
  -y, --yes                          Run apt commands non-interactively
  -h, --help                         Show this help

Notes:
  - Designed for apt-based Linux distributions.
  - Uses sudo automatically when not run as root.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    local cmd
    for cmd in "$@"; do
        command -v "${cmd}" >/dev/null 2>&1 || fail "Missing required command: ${cmd}"
    done
}

run() {
    printf '+ %s\n' "$*"
    "$@"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo-url)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                REPO_URL="$2"
                shift 2
                ;;
            --source-dir)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                SOURCE_DIR="$2"
                shift 2
                ;;
            --build-type)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                BUILD_TYPE="$2"
                shift 2
                ;;
            --purge-distro-libvirt)
                PURGE_DISTRO_LIBVIRT=true
                shift
                ;;
            --skip-service-config)
                SKIP_SERVICE_CONFIG=true
                shift
                ;;
            -y|--yes)
                ASSUME_YES=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                fail "Unknown option: $1 (use --help)"
                ;;
        esac
    done
}

validate_args() {
    case "${BUILD_TYPE}" in
        debug|release) ;;
        *)
            fail "Invalid --build-type '${BUILD_TYPE}'. Use debug or release."
            ;;
    esac
}

prepare_privileges() {
    if [[ "$(id -u)" -eq 0 ]]; then
        SUDO_CMD=()
        TARGET_USER="${SUDO_USER:-${USER:-root}}"
    else
        require_command sudo
        SUDO_CMD=(sudo)
        TARGET_USER="${USER}"
    fi
}

ensure_apt_based_system() {
    command -v apt-get >/dev/null 2>&1 || fail "apt-get not found. This script supports apt-based systems only."
}

install_dependencies() {
    local -a apt_flags=()
    if [[ "${ASSUME_YES}" == true ]]; then
        apt_flags=(-y)
    fi

    if [[ "${PURGE_DISTRO_LIBVIRT}" == true ]]; then
        run "${SUDO_CMD[@]}" apt-get remove --purge "${apt_flags[@]}" \
            libvirt-daemon-system libvirt-clients libvirt0 || true
        run "${SUDO_CMD[@]}" apt-get autoremove --purge "${apt_flags[@]}" || true
    fi

    run "${SUDO_CMD[@]}" apt-get update
    run "${SUDO_CMD[@]}" apt-get install "${apt_flags[@]}" \
        qemu-system-x86 bridge-utils libyajl-dev \
        build-essential autoconf automake libtool \
        libxml2-dev libxslt1-dev libgnutls28-dev libpciaccess-dev \
        libnl-3-dev libnl-route-3-dev pkg-config python3-dev ruby-dev \
        gettext libparted-dev libyaml-dev libssh2-1-dev meson ninja-build \
        libxml2-utils xsltproc libmount-dev libglib2.0-dev python3-docutils \
        virt-manager git
}

sync_source_repo() {
    if [[ -d "${SOURCE_DIR}/.git" ]]; then
        run git -C "${SOURCE_DIR}" fetch --tags --prune
        run git -C "${SOURCE_DIR}" pull --ff-only
    else
        mkdir -p "$(dirname "${SOURCE_DIR}")"
        run git clone "${REPO_URL}" "${SOURCE_DIR}"
    fi
}

build_and_install() {
    local build_dir="${SOURCE_DIR}/build"
    if [[ -f "${build_dir}/build.ninja" ]]; then
        run meson setup "${build_dir}" \
            -Dbuildtype="${BUILD_TYPE}" \
            -Dsystem=true \
            -Ddriver_qemu=enabled \
            --reconfigure
    else
        run meson setup "${build_dir}" \
            -Dbuildtype="${BUILD_TYPE}" \
            -Dsystem=true \
            -Ddriver_qemu=enabled
    fi
    run ninja -C "${build_dir}"
    run "${SUDO_CMD[@]}" ninja -C "${build_dir}" install
}

configure_services() {
    if [[ "${SKIP_SERVICE_CONFIG}" == true ]]; then
        return 0
    fi

    run "${SUDO_CMD[@]}" ldconfig
    run "${SUDO_CMD[@]}" systemctl daemon-reload

    if systemctl list-unit-files | grep -q '^libvirtd\.service'; then
        run "${SUDO_CMD[@]}" systemctl enable --now libvirtd
    fi

    if systemctl list-unit-files | grep -q '^virtlogd\.service'; then
        run "${SUDO_CMD[@]}" systemctl enable --now virtlogd
    fi

    if getent group libvirt >/dev/null 2>&1; then
        if ! id -nG "${TARGET_USER}" | grep -qw libvirt; then
            run "${SUDO_CMD[@]}" usermod -aG libvirt "${TARGET_USER}"
            printf "User '%s' added to 'libvirt' group. Re-login may be required.\n" "${TARGET_USER}"
        fi
    fi
}

main() {
    parse_args "$@"
    validate_args
    prepare_privileges
    require_command systemctl
    ensure_apt_based_system
    install_dependencies
    require_command git meson ninja
    sync_source_repo
    build_and_install
    configure_services
    printf "Libvirt source installation completed successfully.\n"
}

main "$@"
