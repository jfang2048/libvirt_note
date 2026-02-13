#!/usr/bin/env bash
set -euo pipefail

# create-vm-from-base-image.sh
# Creates a VM using a qcow2 overlay backed by an existing base image.
#
# Usage:
#   create-vm-from-base-image.sh --name <vm-name> --base-image <path> [options]
#
# Example:
#   sudo create-vm-from-base-image.sh \
#     --name app01 \
#     --base-image /var/lib/libvirt/images/base-debian12.qcow2 \
#     --memory-mb 4096 --vcpus 4

DEFAULT_IMAGE_DIR="/var/lib/libvirt/images"
DEFAULT_MEMORY_MB=2048
DEFAULT_VCPUS=2
DEFAULT_OS_VARIANT="debian12"
DEFAULT_NETWORK="bridge:vm-br0"
DEFAULT_GRAPHICS="spice"
DEFAULT_VIDEO="qxl"
DEFAULT_CHANNEL="spicevmc"
DEFAULT_GRAPHICS_LISTEN="0.0.0.0"
DEFAULT_BOOT_MODE="uefi"

VM_NAME=""
BASE_IMAGE=""
IMAGE_DIR="${DEFAULT_IMAGE_DIR}"
MEMORY_MB="${DEFAULT_MEMORY_MB}"
VCPUS="${DEFAULT_VCPUS}"
OS_VARIANT="${DEFAULT_OS_VARIANT}"
NETWORK="${DEFAULT_NETWORK}"
GRAPHICS="${DEFAULT_GRAPHICS}"
VIDEO="${DEFAULT_VIDEO}"
CHANNEL="${DEFAULT_CHANNEL}"
GRAPHICS_LISTEN="${DEFAULT_GRAPHICS_LISTEN}"
BOOT_MODE="${DEFAULT_BOOT_MODE}"

usage() {
    cat <<'EOF'
Usage:
  create-vm-from-base-image.sh --name <vm-name> --base-image <path> [options]

Required:
  -n, --name <name>                VM name
  -b, --base-image <path>          Source qcow2 base image path

Options:
      --image-dir <path>           Output image directory (default: /var/lib/libvirt/images)
  -m, --memory-mb <mb>             Guest memory in MB (default: 2048)
  -c, --vcpus <count>              Number of vCPUs (default: 2)
      --os-variant <name>          libosinfo variant (default: debian12)
      --network <spec>             virt-install network spec (default: bridge:vm-br0)
      --graphics <type>            Graphics type (default: spice)
      --video <type>               Video device (default: qxl)
      --channel <name>             Channel device (default: spicevmc)
      --graphics-listen <address>  SPICE listen address (default: 0.0.0.0)
      --boot <mode>                Boot mode or virt-install --boot value (default: uefi)
  -h, --help                       Show this help

Notes:
  - Script creates <image-dir>/<vm-name>.qcow2 as a qcow2 overlay.
  - Script fails if the VM already exists or target disk already exists.
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

is_positive_int() {
    [[ "${1}" =~ ^[0-9]+$ ]] && [[ "${1}" -gt 0 ]]
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                VM_NAME="$2"
                shift 2
                ;;
            -b|--base-image)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                BASE_IMAGE="$2"
                shift 2
                ;;
            --image-dir)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                IMAGE_DIR="$2"
                shift 2
                ;;
            -m|--memory|--memory-mb)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                MEMORY_MB="$2"
                shift 2
                ;;
            -c|--cpu|--vcpus)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                VCPUS="$2"
                shift 2
                ;;
            --os-variant)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                OS_VARIANT="$2"
                shift 2
                ;;
            --network)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                NETWORK="$2"
                shift 2
                ;;
            --graphics)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                GRAPHICS="$2"
                shift 2
                ;;
            --video)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                VIDEO="$2"
                shift 2
                ;;
            --channel)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                CHANNEL="$2"
                shift 2
                ;;
            --graphics-listen)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                GRAPHICS_LISTEN="$2"
                shift 2
                ;;
            --boot)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                BOOT_MODE="$2"
                shift 2
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

cleanup_on_failure() {
    if [[ -n "${VM_IMAGE_PATH:-}" && -f "${VM_IMAGE_PATH}" ]]; then
        rm -f "${VM_IMAGE_PATH}" || true
    fi
    if [[ -n "${VM_NAME}" ]]; then
        virsh undefine "${VM_NAME}" --nvram >/dev/null 2>&1 || true
    fi
}

validate_args() {
    [[ -n "${VM_NAME}" ]] || fail "VM name is required (--name)"
    [[ -n "${BASE_IMAGE}" ]] || fail "Base image is required (--base-image)"
    [[ -f "${BASE_IMAGE}" ]] || fail "Base image not found: ${BASE_IMAGE}"
    is_positive_int "${MEMORY_MB}" || fail "memory-mb must be a positive integer"
    is_positive_int "${VCPUS}" || fail "vcpus must be a positive integer"

    require_command qemu-img virsh virt-install

    mkdir -p "${IMAGE_DIR}"
    VM_IMAGE_PATH="${IMAGE_DIR%/}/${VM_NAME}.qcow2"

    if virsh dominfo "${VM_NAME}" >/dev/null 2>&1; then
        fail "VM '${VM_NAME}' already exists"
    fi
    [[ ! -e "${VM_IMAGE_PATH}" ]] || fail "Target image already exists: ${VM_IMAGE_PATH}"
}

create_overlay_image() {
    qemu-img create -f qcow2 -F qcow2 -b "${BASE_IMAGE}" "${VM_IMAGE_PATH}"
}

run_virt_install() {
    local -a cmd=(
        virt-install
        --name "${VM_NAME}"
        --memory "${MEMORY_MB}"
        --vcpus "${VCPUS}"
        --disk "path=${VM_IMAGE_PATH},format=qcow2,cache=none"
        --os-variant "${OS_VARIANT}"
        --network "${NETWORK}"
        --video "${VIDEO}"
        --channel "${CHANNEL}"
        --graphics "${GRAPHICS},listen=${GRAPHICS_LISTEN}"
        --import
    )

    if [[ "${BOOT_MODE}" == "uefi" ]]; then
        cmd+=(--boot uefi)
    elif [[ "${BOOT_MODE}" != "bios" ]]; then
        cmd+=(--boot "${BOOT_MODE}")
    fi

    "${cmd[@]}"
}

main() {
    parse_args "$@"
    validate_args

    trap cleanup_on_failure ERR
    create_overlay_image
    run_virt_install
    trap - ERR

    printf "VM created from base image: %s\n" "${VM_NAME}"
    printf "Overlay image: %s\n" "${VM_IMAGE_PATH}"
}

main "$@"
