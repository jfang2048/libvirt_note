#!/usr/bin/env bash
set -euo pipefail

# list-vm-disk-source-paths.sh
# Lists libvirt VM disk source file paths.
#
# Usage:
#   list-vm-disk-source-paths.sh [--vm <name>]

VM_FILTER=""

usage() {
    cat <<'EOF'
Usage:
  list-vm-disk-source-paths.sh [options]

Options:
      --vm <name>              Only inspect one VM
  -h, --help                   Show this help

Output:
  Tab-separated columns: vm_name<TAB>disk_source_path
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

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vm)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                VM_FILTER="$2"
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

emit_vm_paths() {
    local vm="$1"
    local found=false
    local path

    while IFS= read -r path; do
        [[ -n "${path}" ]] || continue
        printf "%s\t%s\n" "${vm}" "${path}"
        found=true
    done < <(virsh dumpxml "${vm}" | awk -F"'" '/<source file=/{print $2}')

    if [[ "${found}" == false ]]; then
        printf "%s\t%s\n" "${vm}" "(no file-backed disk source found)"
    fi
}

main() {
    parse_args "$@"
    require_command virsh awk

    printf "vm_name\tdisk_source_path\n"

    if [[ -n "${VM_FILTER}" ]]; then
        virsh dominfo "${VM_FILTER}" >/dev/null 2>&1 || fail "VM not found: ${VM_FILTER}"
        emit_vm_paths "${VM_FILTER}"
        exit 0
    fi

    mapfile -t vms < <(virsh list --all --name | sed '/^[[:space:]]*$/d')
    if [[ "${#vms[@]}" -eq 0 ]]; then
        exit 0
    fi

    local vm
    for vm in "${vms[@]}"; do
        emit_vm_paths "${vm}"
    done
}

main "$@"
