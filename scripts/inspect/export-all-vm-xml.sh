#!/usr/bin/env bash
set -euo pipefail

# export-all-vm-xml.sh
# Exports XML definitions for all libvirt domains into an output directory.
#
# Usage:
#   export-all-vm-xml.sh [--output-dir <path>]

OUTPUT_DIR="./vm-xml"

usage() {
    cat <<'EOF'
Usage:
  export-all-vm-xml.sh [options]

Options:
      --output-dir <path>      Destination directory (default: ./vm-xml)
  -h, --help                   Show this help
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
            --output-dir)
                [[ $# -ge 2 ]] || fail "Missing value for $1"
                OUTPUT_DIR="$2"
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

main() {
    parse_args "$@"
    require_command virsh mkdir

    mkdir -p "${OUTPUT_DIR}"

    mapfile -t vms < <(virsh list --all --name | sed '/^[[:space:]]*$/d')
    if [[ "${#vms[@]}" -eq 0 ]]; then
        printf "No VMs found.\n"
        exit 0
    fi

    local vm
    for vm in "${vms[@]}"; do
        virsh dumpxml "${vm}" > "${OUTPUT_DIR%/}/${vm}.xml"
        printf "Exported: %s\n" "${OUTPUT_DIR%/}/${vm}.xml"
    done
}

main "$@"
