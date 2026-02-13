# Windows 11 GPU Error 43 (Proxmox)

Environment-specific host/IP values in command examples should be treated as placeholders.

---

pve 显卡直通 win11 同时 cpu 直通
error 43 或者根本无法启动

需要支持avx
推荐使用固定 CPU 模型如 "x86-64-v3"，它明确支持 AVX 和 AVX2。
显示是pcid会报错
  host时候，如果hidden pcid起不来，必须启用
  非host ，不hidden ,pcid报错起不来

坚持使用 x86-64-v3或 EPYC-v3 + AVX2配置将完全解决此问题，同时保留您的 AVX 加速功能。

x86-64-v3 这个是支持avx的，就不要直通了

BIOS 中关闭 Resizable BAR


vfio-pci 0000:09:00.0: No more image in the PCI ROM



vtd  vtx 都要开




lscpu 或 cat /proc/cpuinfo | grep avx

可以通过编辑 /etc/pve/virtual-guest/cpu-models.conf 文件自定义 CPU 模型，明确启用 AVX 标志（如 flags +avx;+avx2）

psi参数，关联到对应的事件

---





### Key Points
- It seems likely that the "No more image in the PCI ROM" error and "Error 43" in your Windows 11 VM are related to issues with GPU passthrough in Proxmox, particularly with the NVIDIA RTX 3060.
- Research suggests that ensuring proper VFIO configuration, dumping and using the GPU BIOS, and adjusting VM settings can resolve these errors, but success may depend on your specific hardware and setup.
- The evidence leans toward common fixes like enabling VT-d, blacklisting NVIDIA drivers, and updating GRUB, though some solutions (e.g., vBIOS patching) may be more advanced and controversial due to potential risks.

---

### Direct Answer

#### Overview
You're experiencing issues with passing through an NVIDIA RTX 3060 to a Windows 11 VM in Proxmox, seeing "vfio-pci 0000:09:00.0: No more image in the PCI ROM" and "Error 43" in the Device Manager. This is a common problem with GPU passthrough, and while solutions exist, they may require some technical adjustments.

#### Steps to Resolve
1. **Enable VT-d and Check IOMMU**:
   - Ensure VT-d is enabled in your BIOS, as it's essential for GPU passthrough. Check IOMMU groups with:
     ```bash
     for d in /sys/kernel/iommu_groups/*/devices/*; do n=${d#*/iommu_groups/*}; n=${n%%/*}; printf 'IOMMU group %s ' "$n"; lspci -nns "${d##*/}"; done
     ```
   - This ensures the RTX 3060's IOMMU group is isolated for passthrough.

2. **Blacklist NVIDIA Drivers**:
   - Prevent host conflicts by blacklisting NVIDIA drivers. Edit `/etc/modprobe.d/blacklist.conf` and add:
     ```
     blacklist nouveau
     blacklist nvidia
     blacklist nvidiafb
     ```
   - Update initramfs with `update-initramfs -u` and reboot.

3. **Update GRUB Configuration**:
   - Edit `/etc/default/grub` to include:
     ```
     GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt initcall_blacklist=sysfb_init video=efifb:off"
     ```
   - Run `update-grub` and reboot to apply changes, ensuring IOMMU and framebuffer settings are correct.

4. **Bind GPU to VFIO Early**:
   - Edit `/etc/modprobe.d/vfio.conf` to bind the RTX 3060 to VFIO:
     ```
     options vfio-pci ids=10de:2206,10de:10f0 disable_vga=1
     ```
   - Replace IDs with your GPU's (check with `lspci -nn | grep 10de`) and reboot.

5. **Dump and Use GPU BIOS**:
   - The "No more image in the PCI ROM" error suggests a BIOS issue. Dump it with:
     ```bash
     cd /sys/bus/pci/devices/0000:09:00.0/
     echo 1 > rom
     cat rom > /usr/share/kvm/gpu-3060.bin
     echo 0 > rom
     ```
   - In the VM, add `romfile=gpu-3060.bin` to the PCI device line, e.g., `hostpci0: 0000:09:00.0,pcie=1,x-vga=1,romfile=gpu-3060.bin`.

6. **Configure VM Settings**:
   - Set the VM to use `machine: q35`, enable UEFI with OVMF, and add `vga: none` to disable virtual VGA. Ensure the PCI device is passed through with `pcie=1` and `x-vga=1`.

7. **Install Drivers in Windows**:
   - In the Windows 11 VM, install the latest NVIDIA drivers. If "Error 43" persists, use Display Driver Uninstaller (DDU) to remove old drivers, then reinstall.

#### Additional Tips
- Check host logs with `dmesg | grep vfio` for errors after starting the VM.
- If issues persist, consider advanced solutions like vBIOS patching (e.g., using `nvidia-kvm-patcher`), but proceed cautiously as it can risk damaging the GPU.
- Ensure Proxmox and kernel are updated, as newer versions may fix passthrough issues.

For more details, see [Proxmox Forum: GPU Passthrough Error 43](https://forum.proxmox.com/threads/gpu-passthrough-error-43.139790/) and [Proxmox Forum: NVIDIA RTX 3060 Passthrough](https://forum.proxmox.com/threads/need-help-with-gpu-passthrough-in-proxmox-nvidia-rtx-3060-not-working-properly.127870/).

---

### Comprehensive Technical Survey on GPU Passthrough Issues in Proxmox with NVIDIA RTX 3060

This survey provides an in-depth analysis of the user's query regarding the "vfio-pci 0000:09:00.0: No more image in the PCI ROM" error and "Error 43" when passing through an NVIDIA RTX 3060 to a Windows 11 VM in Proxmox, as of July 23, 2025. The analysis is based on extensive research into community forums, technical documentation, and user-reported solutions, ensuring a thorough understanding of the issue and its resolution.

#### Background and Context
GPU passthrough, facilitated by VFIO (Virtual Function I/O) in Proxmox, allows a virtual machine (VM) to directly access a physical GPU, such as the NVIDIA GeForce RTX 3060, for enhanced performance, particularly for gaming or graphics-intensive applications. However, this process can encounter errors, notably "Error 43" in Windows Device Manager, which indicates the device is disabled due to driver or hardware compatibility issues. The additional error "No more image in the PCI ROM" suggests a problem with the GPU's firmware (BIOS) not being properly read or presented to the guest OS, which is critical for initialization.

Given the user's setup involves Proxmox, a popular open-source virtualization platform, and Windows 11, which has specific hardware and driver requirements, the issue is likely a combination of configuration errors, driver conflicts, and hardware-specific behaviors. The NVIDIA RTX 3060, a relatively modern GPU, may have unique passthrough requirements compared to older models, as evidenced by community reports.

#### Detailed Analysis of the Issue
The "No more image in the PCI ROM" error is a kernel message related to VFIO, indicating that the GPU's ROM (firmware) is not being accessed correctly. This can lead to the Windows VM failing to initialize the GPU, resulting in "Error 43," which is a common issue in NVIDIA GPU passthrough scenarios. Community forums, such as the Proxmox Support Forum, highlight that this problem is particularly prevalent with NVIDIA cards due to their driver behavior in virtualized environments.

Research suggests several root causes:
- **IOMMU and VT-d Configuration**: Improper enabling of Intel VT-d (or AMD equivalent) can prevent proper isolation of the GPU, leading to passthrough failures.
- **Driver Conflicts**: The host system may load NVIDIA drivers, conflicting with the VM's attempt to use the GPU.
- **GPU BIOS Issues**: The GPU's firmware may not be compatible with VFIO, especially if the ROM is not properly dumped or presented.
- **VM Configuration**: Incorrect settings, such as machine type or VGA settings, can cause the VM to fail to recognize the GPU.

#### Step-by-Step Resolution Strategy
Based on the analysis, the following steps provide a comprehensive approach to resolving the issue, ordered by complexity and likelihood of success:

##### 1. Verify BIOS and Host Configuration
- **Enable VT-d**: Ensure VT-d is enabled in the motherboard BIOS, as it is essential for IOMMU, which isolates the GPU for passthrough. Without this, the GPU cannot be exclusively assigned to the VM.
- **Check IOMMU Groups**: Use the command:
  ```bash
  for d in /sys/kernel/iommu_groups/*/devices/*; do n=${d#*/iommu_groups/*}; n=${n%%/*}; printf 'IOMMU group %s ' "$n"; lspci -nns "${d##*/}"; done
  ```
  This lists all IOMMU groups, ensuring the RTX 3060 (e.g., `0000:09:00.0`) is in its own group for passthrough. If not, adjust BIOS settings or consider ACS (Access Control Services) overrides, though this is advanced.

##### 2. Blacklist NVIDIA Drivers on the Host
- To prevent the host from claiming the GPU, edit `/etc/modprobe.d/blacklist.conf` and add:
  ```
  blacklist nouveau
  blacklist nvidia
  blacklist nvidiafb
  ```
- Update the initramfs to apply changes:
  ```bash
  update-initramfs -u
  ```
- Reboot the host. This ensures VFIO can bind to the GPU without conflicts.

##### 3. Configure GRUB for Optimal Passthrough
- Edit `/etc/default/grub` and modify `GRUB_CMDLINE_LINUX_DEFAULT` to include:
  ```
  quiet intel_iommu=on iommu=pt initcall_blacklist=sysfb_init video=efifb:off
  ```
- Update GRUB with:
  ```bash
  update-grub
  ```
- Reboot. These parameters enable IOMMU, prevent framebuffer conflicts, and ensure the system boots without claiming the GPU, addressing the "No more image in the PCI ROM" error.

##### 4. Early Bind GPU to VFIO
- Create or edit `/etc/modprobe.d/vfio.conf` to bind the RTX 3060 to VFIO early, preventing other drivers from claiming it:
  ```
  options vfio-pci ids=10de:2206,10de:10f0 disable_vga=1
  ```
- The IDs (e.g., `10de:2206` for VGA, `10de:10f0` for HDMI Audio) must be verified using:
  ```bash
  lspci -nn | grep 10de
  ```
- Reboot to apply. This step is crucial for ensuring the GPU is available for passthrough from boot.

##### 5. Dump and Use GPU BIOS
- The "No more image in the PCI ROM" error suggests the GPU's firmware is not being read. Dump it with:
  ```bash
  cd /sys/bus/pci/devices/0000:09:00.0/
  echo 1 > rom
  cat rom > /usr/share/kvm/gpu-3060.bin
  echo 0 > rom
  ```
- In the VM configuration, add the ROM file:
  ```
  hostpci0: 0000:09:00.0,pcie=1,x-vga=1,romfile=gpu-3060.bin
  ```
- This ensures the VM can access the GPU's firmware, potentially resolving initialization issues.

##### 6. Configure VM Settings
- In the Proxmox web interface, edit the VM:
  - Set `machine: q35` for better passthrough support.
  - Use UEFI boot with OVMF for compatibility with Windows 11.
  - Add the PCI device with:
    ```
    hostpci0: 0000:09:00.0,pcie=1,x-vga=1,romfile=gpu-3060.bin
    ```
  - Set `vga: none` to disable the virtual VGA device, ensuring the passed-through GPU is used:
    ```
    vga: none
    ```
- Save and start the VM. These settings ensure the VM recognizes the GPU as the primary display.

##### 7. Install and Troubleshoot Drivers in Windows
- In the Windows 11 VM, download and install the latest NVIDIA drivers for the RTX 3060 from the official NVIDIA website.
- If "Error 43" persists, use Display Driver Uninstaller (DDU) in safe mode to remove all NVIDIA drivers, then reinstall. This can resolve driver-related issues causing the error.

##### 8. Monitor and Debug
- After starting the VM, check the host's kernel logs for VFIO-related errors:
  ```bash
  dmesg | grep vfio
  ```
- Look for errors like "timed out waiting for pending transaction" or "not ready after FLR," which indicate reset issues. If present, consider BIOS updates or advanced solutions like vendor-reset.

#### Additional Considerations and Advanced Solutions
- **BIOS Updates**: Some users report reset issues with the RTX 3060, particularly on AM4 motherboards. Check for BIOS updates from your motherboard manufacturer to improve compatibility.
- **vBIOS Patching**: If basic fixes fail, consider patching the GPU's vBIOS using tools like `nvidia-kvm-patcher` (available at [https://github.com/sk1080/nvidia-kvm-patcher](https://github.com/sk1080/nvidia-kvm-patcher)) or `NVIDIA-vBIOS-VFIO-Patcher` ([https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher](https://github.com/Matoking/NVIDIA-vBIOS-VFIO-Patcher)). Note: This is advanced and can risk bricking the GPU if done incorrectly.
- **Kernel and Proxmox Version**: Ensure Proxmox is updated to the latest version (as of July 2025, likely 8.x) and the kernel is recent, as newer versions may include fixes for passthrough issues.

#### Comparative Analysis of Solutions
The following table summarizes common solutions and their effectiveness based on community reports:

| **Solution**                          | **Effectiveness** | **Complexity** | **Risks**                     |
|---------------------------------------|-------------------|----------------|-------------------------------|
| Enable VT-d and Check IOMMU           | High              | Low            | Low, requires BIOS access     |
| Blacklist NVIDIA Drivers              | High              | Low            | Low, standard configuration   |
| Update GRUB with IOMMU Parameters     | High              | Low            | Low, standard configuration   |
| Early Bind to VFIO                    | High              | Medium         | Low, requires reboot          |
| Dump and Use GPU BIOS                 | Medium to High    | Medium         | Low, potential ROM issues     |
| Configure VM with q35 and vga: none   | High              | Low            | Low, standard VM setup        |
| Install Drivers with DDU              | Medium            | Low            | Low, driver-related           |
| vBIOS Patching                       | Variable          | High           | High, risk of bricking GPU    |

#### Conclusion
The combination of enabling VT-d, blacklisting NVIDIA drivers, updating GRUB, early binding to VFIO, dumping and using the GPU BIOS, and configuring the VM appropriately should resolve the "No more image in the PCI ROM" and "Error 43" errors for the NVIDIA RTX 3060 in Proxmox. If issues persist, advanced solutions like vBIOS patching may be necessary, but proceed with caution. Ensure all steps are followed meticulously, and consult community forums for hardware-specific advice.

For further reading, refer to [Proxmox Forum: GPU Passthrough Error 43](https://forum.proxmox.com/threads/gpu-passthrough-error-43.139790/) and [Proxmox Forum: NVIDIA RTX 3060 Passthrough](https://forum.proxmox.com/threads/need-help-with-gpu-passthrough-in-proxmox-nvidia-rtx-3060-not-working-properly.127870/).







---



This error indicates issues with GPU passthrough in Proxmox when trying to pass an NVIDIA GTX 3060 to a Windows 11 VM. Here are the key solutions to resolve this:

## Primary Fixes

**1. Hide VM from NVIDIA Driver**
Add these lines to your VM configuration (`/etc/pve/qemu-server/VMID.conf`):
```
args: -cpu 'host,+kvm_pv_unhalt,+kvm_pv_eoi,hv_vendor_id=NV43FIX,kvm=off'
```

**2. Enable VFIO and IOMMU**
Edit `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction vfio-pci.ids=10de:2504,10de:228e"
```
(Replace the PCI IDs with your actual GPU and audio device IDs from `lspci -nn`)

Update GRUB: `update-grub`

**3. Blacklist NVIDIA Drivers on Host**
Create `/etc/modprobe.d/blacklist.conf`:
```
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
```

**4. Configure VFIO Modules**
Add to `/etc/modules`:
```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

**5. VM Configuration Requirements**
- Machine type: `q35`
- BIOS: `OVMF (UEFI)`
- Add EFI disk
- CPU type: `host` or `kvm64`
- Enable: `PCIe`, `Primary GPU`
- Add both GPU and its audio device

**6. Windows-Specific**
- Install GPU in slot furthest from CPU
- Use latest NVIDIA drivers
- Install in Safe Mode if needed
- Disable Windows driver signature enforcement temporarily

**7. BIOS Settings**
- Enable VT-d/AMD-Vi
- Enable Above 4G Decoding
- Enable Resizable BAR (if available)
- Set primary display to integrated graphics

After making these changes, reboot the Proxmox host and recreate the VM configuration. The "No more image in the PCI ROM" error should resolve once the GPU is properly isolated from the host and passed through correctly.



---















