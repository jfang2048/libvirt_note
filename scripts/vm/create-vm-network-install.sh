#!/usr/bin/env bash
set -euo pipefail

# create-vm-network-install.sh
# Creates a new VM with virt-install using network boot by default.
#
# Usage:
#   create-vm-network-install.sh --name <vm-name> [options]
#
# Example:
#   create-vm-network-install.sh --name demo01 --memory-mb 4096 --vcpus 4 --disk-gb 40

DEFAULT_MEMORY_MB=2048
DEFAULT_VCPUS=2
DEFAULT_DISK_GB=20
DEFAULT_OS_VARIANT="debian12"
DEFAULT_NETWORK="bridge:vm-br0"
DEFAULT_GRAPHICS="spice"
DEFAULT_VIDEO="qxl"
DEFAULT_CHANNEL="spicevmc"
DEFAULT_IMAGE_DIR="/var/lib/libvirt/images"
DEFAULT_BOOT="uefi"

VM_NAME=""
MEMORY_MB="${DEFAULT_MEMORY_MB}"
VCPUS="${DEFAULT_VCPUS}"
DISK_GB="${DEFAULT_DISK_GB}"
OS_VARIANT="${DEFAULT_OS_VARIANT}"
NETWORK="${DEFAULT_NETWORK}"
GRAPHICS="${DEFAULT_GRAPHICS}"
VIDEO="${DEFAULT_VIDEO}"
CHANNEL="${DEFAULT_CHANNEL}"
IMAGE_DIR="${DEFAULT_IMAGE_DIR}"
BOOT_MODE="${DEFAULT_BOOT}"
USE_PXE=true

usage() {
    cat <<'EOF'
Usage:
  create-vm-network-install.sh --name <vm-name> [options]

Required:
  -n, --name <name>                VM name

Options:
  -m, --memory-mb <mb>             Guest memory in MB (default: 2048)
  -c, --vcpus <count>              Number of vCPUs (default: 2)
  -d, --disk-gb <gb>               Disk size in GB (default: 20)
      --os-variant <name>          libosinfo variant (default: debian12)
      --network <spec>             virt-install network spec (default: bridge:vm-br0)
      --graphics <type>            Graphics type (default: spice)
      --video <type>               Video device (default: qxl)
      --channel <name>             Channel device (default: spicevmc)
      --image-dir <path>           Disk image directory (default: /var/lib/libvirt/images)
      --boot <mode>                Boot mode or virt-install --boot value (default: uefi)
      --no-pxe                     Disable PXE flag
  -h, --help                       Show this help

Notes:
  - Script is idempotent for VM name: it will fail if the VM already exists.
  - Script fails if target disk file already exists.
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
            -d|--disk|--disk-gb)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                DISK_GB="$2"
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
            --image-dir)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                IMAGE_DIR="$2"
                shift 2
                ;;
            --boot)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                BOOT_MODE="$2"
                shift 2
                ;;
            --no-pxe)
                USE_PXE=false
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
    [[ -n "${VM_NAME}" ]] || fail "VM name is required (--name)"
    is_positive_int "${MEMORY_MB}" || fail "memory-mb must be a positive integer"
    is_positive_int "${VCPUS}" || fail "vcpus must be a positive integer"
    is_positive_int "${DISK_GB}" || fail "disk-gb must be a positive integer"

    require_command virsh virt-install

    if virsh dominfo "${VM_NAME}" >/dev/null 2>&1; then
        fail "VM '${VM_NAME}' already exists"
    fi

    mkdir -p "${IMAGE_DIR}"
    VM_IMAGE_PATH="${IMAGE_DIR%/}/${VM_NAME}.qcow2"
    [[ ! -e "${VM_IMAGE_PATH}" ]] || fail "Disk image already exists: ${VM_IMAGE_PATH}"
}

run_virt_install() {
    local -a cmd=(
        virt-install
        --name "${VM_NAME}"
        --memory "${MEMORY_MB}"
        --vcpus "${VCPUS}"
        --disk "path=${VM_IMAGE_PATH},size=${DISK_GB},format=qcow2,cache=none"
        --os-variant "${OS_VARIANT}"
        --network "${NETWORK}"
        --graphics "${GRAPHICS}"
        --video "${VIDEO}"
        --channel "${CHANNEL}"
    )

    if [[ "${USE_PXE}" == true ]]; then
        cmd+=(--pxe)
    fi

    if [[ "${BOOT_MODE}" == "uefi" ]]; then
        cmd+=(--boot uefi)
    elif [[ "${BOOT_MODE}" != "bios" ]]; then
        cmd+=(--boot "${BOOT_MODE}")
    fi

    "${cmd[@]}"
    printf "VM creation initiated: %s\n" "${VM_NAME}"
}

main() {
    parse_args "$@"
    validate_args
    run_virt_install
}

main "$@"
