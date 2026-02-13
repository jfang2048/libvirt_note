#!/usr/bin/env bash
set -euo pipefail

# remove-vm.sh
# Safely remove a libvirt VM and optionally its disk artifacts.
#
# Usage:
#   sudo remove-vm.sh --name <vm-name> [--delete-disks] [--image-dir <path>] [--yes]

VM_NAME=""
IMAGE_DIR="/var/lib/libvirt/images"
DELETE_DISKS=false
ASSUME_YES=false

usage() {
    cat <<'EOF'
Usage:
  remove-vm.sh --name <vm-name> [options]

Required:
  -n, --name <name>            VM name to remove

Options:
      --image-dir <path>       VM image directory (default: /var/lib/libvirt/images)
      --delete-disks           Also remove matching disk files (<name>.*)
  -y, --yes                    Non-interactive mode, skip confirmation prompts
  -h, --help                   Show this help

Notes:
  - Requires root privileges.
  - If VM is running, script asks before forced shutdown (unless --yes).
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
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

confirm() {
    local prompt="$1"
    local answer=""

    if [[ "${ASSUME_YES}" == true ]]; then
        return 0
    fi

    read -r -p "${prompt} [y/N]: " answer
    [[ "${answer}" =~ ^[Yy]$ ]]
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                VM_NAME="$2"
                shift 2
                ;;
            --image-dir)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                IMAGE_DIR="$2"
                shift 2
                ;;
            --delete-disks)
                DELETE_DISKS=true
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

ensure_vm_exists() {
    virsh dominfo "${VM_NAME}" >/dev/null 2>&1 || fail "VM does not exist: ${VM_NAME}"
}

stop_vm_if_needed() {
    local state
    state="$(virsh domstate "${VM_NAME}" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if [[ "${state}" != "shut off" ]]; then
        confirm "VM '${VM_NAME}' is '${state}'. Force stop it?" || fail "Operation canceled."
        virsh destroy "${VM_NAME}"
    fi
}

undefine_vm() {
    confirm "Undefine VM '${VM_NAME}'?" || fail "Operation canceled."
    if ! virsh undefine "${VM_NAME}" --nvram; then
        # Fallback for guests without NVRAM.
        virsh undefine "${VM_NAME}"
    fi
}

remove_vm_disks() {
    local removed_any=false
    local file

    if [[ "${DELETE_DISKS}" == false ]]; then
        if ! confirm "Also remove disk files matching '${VM_NAME}.*' in '${IMAGE_DIR}'?"; then
            return 0
        fi
    fi

    if [[ ! -d "${IMAGE_DIR}" ]]; then
        printf "Image directory not found, skipping disk cleanup: %s\n" "${IMAGE_DIR}"
        return 0
    fi

    while IFS= read -r -d '' file; do
        rm -f "${file}"
        printf "Removed: %s\n" "${file}"
        removed_any=true
    done < <(find "${IMAGE_DIR}" -maxdepth 1 -type f -name "${VM_NAME}.*" -print0)

    if [[ "${removed_any}" == false ]]; then
        printf "No matching disk files found under: %s\n" "${IMAGE_DIR}"
    fi
}

main() {
    parse_args "$@"
    [[ -n "${VM_NAME}" ]] || fail "VM name is required (--name)"

    require_root
    require_command virsh find rm

    ensure_vm_exists
    stop_vm_if_needed
    undefine_vm
    remove_vm_disks

    printf "VM removal completed: %s\n" "${VM_NAME}"
}

main "$@"
