# GPU Passthrough And VFIO

Environment-specific host/IP values in command examples should be treated as placeholders.

$ cat /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTLABEL="PRIMARY" rootfstype=xfs add_efi_memmap intel_iommu=on iommu=pt rd.driver.pre=vfio-pci
#resume=PARTLABEL="SWAP" nomodeset i915.modeset=0
bootctl update

$ cat /etc/modprobe.d/vfio.conf
options vfio-pci ids=10de:2204,10de:1aef
$ cat /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0

You will probably want to have a spare monitor or one with multiple input ports connected to different GPUs (the passthrough GPU will not display anything if there is no screen plugged in and using a VNC or Spice connection will not help your performance)


[ref](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)

#### Hardware requirements

    1. CPU 必须支持硬件虚拟化（为了使用 kvm）和 IOMMU（为了使用 VGA 直通）
    2. 主板必须支持 IOMMU
    3. 分配给客户机的 GPU 的 ROM 必须支持 UEFI

### set IOMMU
    1. bios启用
```
Secure Boot  [Enabled] 
Fast Boot    [Enabled] 
AC BACK      [Always Off]>[Memory]
IOMMU        [Enabled] 
AMD CPU FTPM [Enabled]
SVM Mode     [Enabled]
```
    2. 内核参数,设置`iommu=pt`

```bash
# IOMMU
vim /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt rd.driver.pre=vfio-pci"

update-grub
reboot
```
    3. `dmesg | grep -e "DMAR" -e "IOMMU"`检查

### validate

 *一个 IOMMU 组是将物理设备直通给虚拟机的最小单位*

```bash
#!/bin/bash

# Check if IOMMU is enabled
if ! dmesg | grep -e "DMAR" -e "IOMMU" | grep -q "enabled"; then
    echo "WARNING: IOMMU doesn't appear to be enabled!"
    echo "Check your BIOS settings and kernel parameters."
fi

# Display all IOMMU groups and their devices
echo "Listing all IOMMU Groups:"
shopt -s nullglob
for d in /sys/kernel/iommu_groups/*/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s: ' "$n"
    lspci -nns "${d##*/}"
done
```

### vfio-pci

```bash
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/0000:09:00.1/driver_override
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/0000:09:00.2/driver_override
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/0000:09:00.3/driver_override
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/0000:0a:00.1/driver_override
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/0000:0a:00.2/driver_override
echo "vfio-pci" | sudo tee /sys/bus/pci/devices/0000:0a:00.3/driver_override
```

---

#### Restructure

```bash
#!/bin/bash

# 1. 解绑原驱动并绑定 vfio-pci
for dev in 0000:09:00.{1..3} 0000:0a:00.{1..3}; do
    echo "$dev" | sudo tee /sys/bus/pci/devices/$dev/driver/unbind >/dev/null 2>&1
    
    echo "vfio-pci" | sudo tee /sys/bus/pci/devices/$dev/driver_override >/dev/null
    
    echo "$dev" | sudo tee /sys/bus/pci/drivers_probe >/dev/null
done

# 2. 验证绑定结果
for dev in 0000:09:00.{1..3} 0000:0a:00.{1..3}; do
    echo -e "\nDevice: $dev"
    lspci -ks ${dev#0000:} | grep "Kernel driver in use"
done

```
    如需开机自动绑定，需在 /etc/modprobe.d/vfio.conf 添加设备 ID
`options vfio-pci ids=10de:13c2,10de:0fbb`
