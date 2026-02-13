# Windows 11 GPU Error 43 (Proxmox)

Environment-specific host/IP values in command examples should be treated as placeholders.

## Field Notes

pve 显卡直通 win11 同时 cpu 直通，`Error 43` 或者根本无法启动。

- 需要支持 `avx`。
- 推荐使用固定 CPU 模型如 `x86-64-v3`，它明确支持 `AVX` 和 `AVX2`。
- 显示是 `pcid` 会报错：
  - `host` 时候，如果 hidden `pcid` 起不来，必须启用。
  - 非 `host`，不 hidden，`pcid` 报错起不来。
- 坚持使用 `x86-64-v3` 或 `EPYC-v3 + AVX2` 配置将完全解决此问题，同时保留 AVX 加速功能。
- `x86-64-v3` 是支持 `avx` 的，就不要直通了。
- BIOS 中关闭 `Resizable BAR`。
- `vfio-pci 0000:09:00.0: No more image in the PCI ROM`。
- `vtd`、`vtx` 都要开。
- `lscpu` 或 `cat /proc/cpuinfo | grep avx`。
- 可以通过编辑 `/etc/pve/virtual-guest/cpu-models.conf` 文件自定义 CPU 模型，明确启用 AVX 标志（如 `flags +avx;+avx2`）。
- `psi` 参数，关联到对应的事件。

## Key Points

- It seems likely that the "No more image in the PCI ROM" error and "Error 43" in your Windows 11 VM are related to issues with GPU passthrough in Proxmox, particularly with the NVIDIA RTX 3060.
- Research suggests that ensuring proper VFIO configuration, dumping and using the GPU BIOS, and adjusting VM settings can resolve these errors, but success may depend on your specific hardware and setup.
- The evidence leans toward common fixes like enabling VT-d, blacklisting NVIDIA drivers, and updating GRUB, though some solutions (for example, vBIOS patching) may be more advanced and controversial due to potential risks.

## Direct Answer

### Overview

You're experiencing issues with passing through an NVIDIA RTX 3060 to a Windows 11 VM in Proxmox, seeing `vfio-pci 0000:09:00.0: No more image in the PCI ROM` and `Error 43` in Device Manager. This is a common GPU passthrough problem and may require multiple configuration changes.

### Steps to Resolve

1. **Enable VT-d and Check IOMMU**
   - Ensure VT-d is enabled in BIOS.
   - Check IOMMU groups:

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do n=${d#*/iommu_groups/*}; n=${n%%/*}; printf 'IOMMU group %s ' "$n"; lspci -nns "${d##*/}"; done
```

2. **Blacklist NVIDIA Drivers**
   - Edit `/etc/modprobe.d/blacklist.conf` and add:

```text
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
```

   - Apply and reboot:

```bash
update-initramfs -u
```

3. **Update GRUB Configuration**
   - Edit `/etc/default/grub` and include:

```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt initcall_blacklist=sysfb_init video=efifb:off"
```

   - Apply:

```bash
update-grub
```

4. **Bind GPU to VFIO Early**
   - Edit `/etc/modprobe.d/vfio.conf`:

```text
options vfio-pci ids=10de:2206,10de:10f0 disable_vga=1
```

   - Replace IDs with your own values from `lspci -nn | grep 10de`.

5. **Dump and Use GPU BIOS**
   - Dump ROM:

```bash
cd /sys/bus/pci/devices/0000:09:00.0/
echo 1 > rom
cat rom > /usr/share/kvm/gpu-3060.bin
echo 0 > rom
```

   - Add ROM file in VM config:

```text
hostpci0: 0000:09:00.0,pcie=1,x-vga=1,romfile=gpu-3060.bin
```

6. **Configure VM Settings**
   - Set `machine: q35`.
   - Use UEFI (`OVMF`).
   - Set `vga: none`.
   - Keep passthrough options like `pcie=1` and `x-vga=1`.

7. **Install Drivers in Windows**
   - Install the latest NVIDIA drivers in the guest.
   - If `Error 43` persists, use DDU and reinstall.

### Additional Tips

- Check host logs with `dmesg | grep vfio`.
- If issues persist, advanced options include vBIOS patching (for example `nvidia-kvm-patcher`), but this has risk.
- Keep Proxmox and kernel updated.

For more details, see:

- [Proxmox Forum: GPU Passthrough Error 43](https://forum.proxmox.com/threads/gpu-passthrough-error-43.139790/)
- [Proxmox Forum: NVIDIA RTX 3060 Passthrough](https://forum.proxmox.com/threads/need-help-with-gpu-passthrough-in-proxmox-nvidia-rtx-3060-not-working-properly.127870/)

## Comprehensive Technical Survey on GPU Passthrough Issues in Proxmox with NVIDIA RTX 3060

This survey provides an in-depth analysis of the query regarding the `vfio-pci 0000:09:00.0: No more image in the PCI ROM` error and `Error 43` when passing through an NVIDIA RTX 3060 to a Windows 11 VM in Proxmox, as of July 23, 2025. The analysis is based on community forums, technical documentation, and user-reported solutions.

### Background and Context

GPU passthrough, via VFIO in Proxmox, allows a VM to directly access a physical GPU. A common failure mode is `Error 43` in Windows Device Manager (driver/hardware compatibility path), plus VFIO ROM-read issues (`No more image in the PCI ROM`).

Given Proxmox + Windows 11 requirements, the issue is often a combination of:

- configuration problems,
- host/guest driver conflicts,
- GPU firmware behavior,
- VM machine/firmware settings.

### Detailed Analysis of the Issue

The `No more image in the PCI ROM` message suggests the GPU ROM is not exposed/read as expected. This can cascade into Windows failing to initialize the card (`Error 43`). Community reports indicate NVIDIA consumer cards are particularly sensitive to VM configuration details.

Potential root causes include:

- **IOMMU and VT-d Configuration**: missing or incorrect host isolation.
- **Driver Conflicts**: host NVIDIA modules binding the device.
- **GPU BIOS Issues**: ROM compatibility/dump/presentation failures.
- **VM Configuration**: machine type, VGA, and firmware mismatch.

### Step-by-Step Resolution Strategy

#### 1. Verify BIOS and Host Configuration

- Enable VT-d in BIOS.
- Check IOMMU groups:

```bash
for d in /sys/kernel/iommu_groups/*/devices/*; do n=${d#*/iommu_groups/*}; n=${n%%/*}; printf 'IOMMU group %s ' "$n"; lspci -nns "${d##*/}"; done
```

If the RTX 3060 is not isolated, adjust BIOS settings or evaluate ACS overrides (advanced).

#### 2. Blacklist NVIDIA Drivers on the Host

Edit `/etc/modprobe.d/blacklist.conf`:

```text
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
```

Apply:

```bash
update-initramfs -u
```

Reboot host.

#### 3. Configure GRUB for Optimal Passthrough

Edit `/etc/default/grub`:

```text
quiet intel_iommu=on iommu=pt initcall_blacklist=sysfb_init video=efifb:off
```

Apply:

```bash
update-grub
```

Reboot.

#### 4. Early Bind GPU to VFIO

Edit `/etc/modprobe.d/vfio.conf`:

```text
options vfio-pci ids=10de:2206,10de:10f0 disable_vga=1
```

Verify IDs with:

```bash
lspci -nn | grep 10de
```

Reboot.

#### 5. Dump and Use GPU BIOS

```bash
cd /sys/bus/pci/devices/0000:09:00.0/
echo 1 > rom
cat rom > /usr/share/kvm/gpu-3060.bin
echo 0 > rom
```

VM config:

```text
hostpci0: 0000:09:00.0,pcie=1,x-vga=1,romfile=gpu-3060.bin
```

#### 6. Configure VM Settings

- `machine: q35`
- UEFI (`OVMF`)
- passthrough line with `pcie=1,x-vga=1,romfile=...`
- `vga: none`

#### 7. Install and Troubleshoot Drivers in Windows

Install latest NVIDIA drivers in guest. If `Error 43` remains, clean drivers with DDU and reinstall.

#### 8. Monitor and Debug

```bash
dmesg | grep vfio
```

Watch for reset/FLR errors (`timed out waiting for pending transaction`, `not ready after FLR`).

### Additional Considerations and Advanced Solutions

- **BIOS updates**: may improve reset behavior on certain boards.
- **vBIOS patching**:
  - <https://github.com/sk1080/nvidia-kvm-patcher>
  - <https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher>
  - advanced, higher risk.
- **Kernel/Proxmox version**: newer versions may contain passthrough fixes.

### Comparative Analysis of Solutions

| Solution | Effectiveness | Complexity | Risks |
| --- | --- | --- | --- |
| Enable VT-d and check IOMMU | High | Low | Low, requires BIOS access |
| Blacklist NVIDIA drivers | High | Low | Low, standard configuration |
| Update GRUB with IOMMU parameters | High | Low | Low, standard configuration |
| Early bind to VFIO | High | Medium | Low, requires reboot |
| Dump and use GPU BIOS | Medium to High | Medium | Low, potential ROM issues |
| Configure VM with `q35` and `vga: none` | High | Low | Low, standard VM setup |
| Install drivers with DDU | Medium | Low | Low, driver-related |
| vBIOS patching | Variable | High | High, risk of bricking GPU |

### Conclusion

The combined path of VT-d/IOMMU verification, host driver blacklisting, GRUB tuning, early VFIO binding, ROM handling, and correct VM firmware/machine settings should address the common `No more image in the PCI ROM` + `Error 43` pattern for RTX 3060 passthrough on Proxmox.

For further reading:

- [Proxmox Forum: GPU Passthrough Error 43](https://forum.proxmox.com/threads/gpu-passthrough-error-43.139790/)
- [Proxmox Forum: NVIDIA RTX 3060 Passthrough](https://forum.proxmox.com/threads/need-help-with-gpu-passthrough-in-proxmox-nvidia-rtx-3060-not-working-properly.127870/)

## Primary Fixes (Condensed Checklist)

This error indicates GPU passthrough issues in Proxmox when passing an NVIDIA GTX 3060 to a Windows 11 VM. Key fixes:

1. **Hide VM from NVIDIA Driver**
   - Add to `/etc/pve/qemu-server/VMID.conf`:

```text
args: -cpu 'host,+kvm_pv_unhalt,+kvm_pv_eoi,hv_vendor_id=NV43FIX,kvm=off'
```

2. **Enable VFIO and IOMMU**
   - Edit `/etc/default/grub`:

```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction vfio-pci.ids=10de:2504,10de:228e"
```

   - Replace PCI IDs with `lspci -nn` output.
   - Update GRUB: `update-grub`.

3. **Blacklist NVIDIA Drivers on Host**
   - Create `/etc/modprobe.d/blacklist.conf`:

```text
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
```

4. **Configure VFIO Modules**
   - Add to `/etc/modules`:

```text
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

5. **VM Configuration Requirements**
   - Machine type: `q35`
   - BIOS: `OVMF (UEFI)`
   - Add EFI disk
   - CPU type: `host` or `kvm64`
   - Enable: `PCIe`, `Primary GPU`
   - Add both GPU and its audio device

6. **Windows-Specific**
   - Install GPU in slot furthest from CPU
   - Use latest NVIDIA drivers
   - Install in Safe Mode if needed
   - Temporarily disable Windows driver signature enforcement

7. **BIOS Settings**
   - Enable VT-d/AMD-Vi
   - Enable Above 4G Decoding
   - Enable Resizable BAR (if available)
   - Set primary display to integrated graphics

After making these changes, reboot the Proxmox host and recreate the VM configuration. The `No more image in the PCI ROM` error should resolve once the GPU is properly isolated from the host and passed through correctly.
