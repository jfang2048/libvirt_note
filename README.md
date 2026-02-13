# KVM Virtualization Knowledge Base

This repository contains operational notes, troubleshooting guides, and utility scripts for KVM/libvirt, GPU passthrough, Proxmox VE, and LXC/LXD workflows.

## Repository Structure

```text
.
├── docs/            # Thematic documentation (KVM, GPU, Proxmox, containers)
├── scripts/         # Operational automation scripts (setup, VM lifecycle, inspection)
└── references/      # Reference-only materials (books/PDFs)
```

## Documentation Map

- `docs/kvm/`: KVM setup, VM lifecycle, optimization, troubleshooting, and install examples.
- `docs/gpu/`: GPU passthrough and GPU virtualization references.
- `docs/proxmox/`: Proxmox operational notes and Windows GPU passthrough debugging.
- `docs/containers/`: LXC/LXD deployment and resource-management notes.
- `docs/notes/`: Additional operator notes and ideas.

Start from `docs/README.md` for a topic-oriented index.

## Scripts

- `scripts/setup/`: Host setup and source build workflows.
- `scripts/vm/`: VM create/remove lifecycle tools.
- `scripts/inspect/`: VM metadata and qcow2 inspection utilities.

See `scripts/README.md` for usage examples and options.

## Public Release Notes

- Machine-specific and person-specific references were removed from executable scripts.
- Script names are standardized with kebab-case and grouped by purpose.
- Duplicate inspection logic was consolidated into a single maintained script.
- Documentation was reorganized by technical domain for easier navigation.

## References

Reference PDFs are retained under `references/books/` as supplementary material only.
See `references/README.md` for details.
