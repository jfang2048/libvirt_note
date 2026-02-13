# Documentation Index

This folder is organized as a unified knowledge base by operational domain.

## Domains

- `kvm/`: KVM and libvirt host setup, VM operations, performance tuning, and troubleshooting.
- `gpu/`: GPU passthrough and virtualization notes (VFIO, vGPU references).
- `proxmox/`: Proxmox VE storage, passthrough, and platform-specific operations.
- `containers/`: LXC/LXD setup and resource controls.
- `notes/`: Supplemental operator ideas and migration notes.

## Suggested Reading Order

1. `kvm/setup-and-prerequisites.md`
2. `kvm/vm-lifecycle-and-operations.md`
3. `kvm/performance-optimization.md`
4. `kvm/troubleshooting.md`
5. Domain-specific docs under `gpu/`, `proxmox/`, and `containers/`

## Documentation Conventions

- Commands are provided as operator runbooks, not turnkey automation.
- Environment-specific values in examples should be replaced with local values before use.
- Keep new file names in kebab-case and place content in the matching domain folder.
