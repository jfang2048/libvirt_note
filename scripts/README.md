# Script Catalog

All scripts are organized by purpose and use a consistent CLI style (`--help`, validated arguments, and error handling).

## Setup

- `setup/install-libvirt-from-source.sh`
  - Build and install libvirt from source on apt-based systems.
  - Example:
    - `./scripts/setup/install-libvirt-from-source.sh --source-dir ./build/libvirt-src --build-type debug --yes`

## VM Lifecycle

- `vm/create-vm-network-install.sh`
  - Create a VM using virt-install and network boot by default.
  - Example:
    - `./scripts/vm/create-vm-network-install.sh --name testvm --memory-mb 4096 --vcpus 4 --disk-gb 40`

- `vm/create-vm-from-base-image.sh`
  - Create a VM from a qcow2 base image using a linked overlay.
  - Example:
    - `sudo ./scripts/vm/create-vm-from-base-image.sh --name app01 --base-image /var/lib/libvirt/images/base.qcow2`

- `vm/remove-vm.sh`
  - Remove a VM safely and optionally delete related disk files.
  - Example:
    - `sudo ./scripts/vm/remove-vm.sh --name app01 --delete-disks`

## Inspection

- `inspect/export-all-vm-xml.sh`
  - Export all VM XML definitions.
  - Example:
    - `./scripts/inspect/export-all-vm-xml.sh --output-dir ./artifacts/vm-xml`

- `inspect/list-vm-disk-source-paths.sh`
  - Print VM names and their file-backed disk source paths.
  - Example:
    - `./scripts/inspect/list-vm-disk-source-paths.sh`

- `inspect/detect-qcow2-boot-mode.sh`
  - Detect EFI vs BIOS boot markers for qcow2 images.
  - Example:
    - `sudo ./scripts/inspect/detect-qcow2-boot-mode.sh --directory /var/lib/libvirt/images`
