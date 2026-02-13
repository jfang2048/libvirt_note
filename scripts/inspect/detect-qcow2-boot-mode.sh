#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# detect-qcow2-boot-mode.sh
# Detects likely boot mode (EFI/BIOS) for qcow2 images by probing partition metadata.
#
# Usage:
#   sudo detect-qcow2-boot-mode.sh [--directory <path>] [--nbd-device <dev>] [--max-part <n>]

TARGET_DIR="."
NBD_DEVICE="/dev/nbd0"
MAX_PART=16
NO_COLOR=false
LOADED_NBD_BY_SCRIPT=false

usage() {
    cat <<'EOF'
Usage:
  detect-qcow2-boot-mode.sh [options]

Options:
  -d, --directory <path>       Directory containing qcow2 files (default: current directory)
      --nbd-device <device>    NBD device to use (default: /dev/nbd0)
      --max-part <count>       max_part value when loading nbd module (default: 16)
      --no-color               Disable ANSI color output
  -h, --help                   Show this help

Notes:
  - Requires root privileges.
  - Uses qemu-nbd + fdisk + parted.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

is_positive_int() {
    [[ "${1}" =~ ^[0-9]+$ ]] && [[ "${1}" -gt 0 ]]
}

require_root() {
    [[ "$(id -u)" -eq 0 ]] || fail "This script must be run as root."
}

require_command() {
    local cmd
    for cmd in "$@"; do
        command -v "${cmd}" >/dev/null 2>&1 || fail "Missing required command: ${cmd}"
    done
}

color() {
    local code="$1"
    shift
    if [[ "${NO_COLOR}" == true ]] || [[ ! -t 1 ]]; then
        printf "%s" "$*"
    else
        printf "\033[%sm%s\033[0m" "${code}" "$*"
    fi
}

cleanup() {
    qemu-nbd -d "${NBD_DEVICE}" >/dev/null 2>&1 || true
    if [[ "${LOADED_NBD_BY_SCRIPT}" == true ]]; then
        modprobe -r nbd >/dev/null 2>&1 || true
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--directory)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                TARGET_DIR="$2"
                shift 2
                ;;
            --nbd-device)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                NBD_DEVICE="$2"
                shift 2
                ;;
            --max-part)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                MAX_PART="$2"
                shift 2
                ;;
            --no-color)
                NO_COLOR=true
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

prepare_environment() {
    [[ -d "${TARGET_DIR}" ]] || fail "Directory not found: ${TARGET_DIR}"
    is_positive_int "${MAX_PART}" || fail "max-part must be a positive integer"
    require_command modprobe qemu-nbd fdisk parted

    if [[ ! -e "${NBD_DEVICE}" ]]; then
        modprobe nbd "max_part=${MAX_PART}"
        LOADED_NBD_BY_SCRIPT=true
    elif [[ ! -b "${NBD_DEVICE}" ]]; then
        fail "NBD path exists but is not a block device: ${NBD_DEVICE}"
    fi

    if [[ ! -b "${NBD_DEVICE}" ]]; then
        modprobe nbd "max_part=${MAX_PART}"
        LOADED_NBD_BY_SCRIPT=true
        [[ -b "${NBD_DEVICE}" ]] || fail "Unable to initialize NBD device: ${NBD_DEVICE}"
    fi
}

detect_boot_mode_for_image() {
    local image_path="$1"
    local boot_mode="UNKNOWN"

    qemu-nbd -d "${NBD_DEVICE}" >/dev/null 2>&1 || true
    qemu-nbd -c "${NBD_DEVICE}" "${image_path}"
    sleep 1

    if ! fdisk -l "${NBD_DEVICE}" >/dev/null 2>&1; then
        boot_mode="UNREADABLE_PARTITION_TABLE"
    elif fdisk -l "${NBD_DEVICE}" | grep -q 'EFI System'; then
        boot_mode="EFI (EFI System Partition found by fdisk)"
    elif parted -m "${NBD_DEVICE}" print 2>/dev/null | grep -q 'esp'; then
        boot_mode="EFI (ESP flag found by parted)"
    else
        boot_mode="BIOS (no EFI marker detected)"
    fi

    qemu-nbd -d "${NBD_DEVICE}" >/dev/null 2>&1 || true

    printf "%s\t%s\n" "$(basename "${image_path}")" "${boot_mode}"
}

main() {
    parse_args "$@"
    require_root
    trap cleanup EXIT
    prepare_environment

    mapfile -t images < <(find "${TARGET_DIR}" -maxdepth 1 -type f -name '*.qcow2' | sort)
    if [[ "${#images[@]}" -eq 0 ]]; then
        fail "No qcow2 files found in directory: ${TARGET_DIR}"
    fi

    color "1;34" "QCOW2 Boot Mode Detection"
    printf "\n"
    printf "directory\t%s\n" "${TARGET_DIR}"
    printf "nbd_device\t%s\n" "${NBD_DEVICE}"
    printf "\n"
    printf "image\tboot_mode\n"

    local img
    for img in "${images[@]}"; do
        detect_boot_mode_for_image "${img}"
    done
}

main "$@"
