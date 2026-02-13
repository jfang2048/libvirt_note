# GPU Virtualization Landscape

Environment-specific host/IP values in command examples should be treated as placeholders.

## Projects

- [DualCoder/vgpu_unlock](https://github.com/DualCoder/vgpu_unlock)
  - Unlock vGPU functionality for consumer-grade NVIDIA GPUs.
- [Arc-Compute/LibVF.IO](https://github.com/Arc-Compute/LibVF.IO)
  - Vendor-neutral GPU multiplexing tool driven by YAML and VFIO.

## Notes

- Allocate VRAM appropriately; guest and host contention can reduce performance.
- Historical behavior in Intel GVT-g environments showed near-full performance when contention was low.

## `vgpu_unlock`

- [GPU Virtualization Wiki: System Requirements](https://krutavshah.github.io/GPU_Virtualization-Wiki/overview.html#system-requirements)
