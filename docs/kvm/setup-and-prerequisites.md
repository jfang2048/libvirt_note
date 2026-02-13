# KVM Setup and Prerequisites

Environment-specific host/IP values in command examples should be treated as placeholders.

## Uninstall

```bash
apt-get purge virt-manager
apt-get remove --purge libvirt*
apt-get autoremove --purge
apt-get clean
apt-get autoclean
```

## Install

```bash
apt update
apt upgrade
apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
systemctl status libvirtd
```

## Bug Fix

If you see the following error from `libvirt-guests.sh`:

```text
libvirt-guests.sh[119940]: error: operation failed: libvirt: error: cannot execute binary /usr/libexec/libvirt_iohelper
```

Apply executable permission:

```bash
sudo chmod +x /usr/libexec/libvirt_iohelper
```

## Pre-Install

```bash
sudo apt-get install qemu-utils libguestfs-tools
```

Host `/etc/libvirt/qemu.conf`:

```ini
security_driver = "none"
vnc_tls = 0
```

```bash
systemctl restart libvirtd
```

## Host Network Bridge

### Create Bridge

```bash
apt install bridge-utils

ip link add name vm-br0 type bridge
ip link set ens5f0 master vm-br0
ip link set vm-br0 up
ip link set ens5f0 up
```

### Example `/etc/network/interfaces`

```ini
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto ens5f0
allow-hotplug ens5f0
iface ens5f0 inet manual

auto vm-br0
iface vm-br0 inet dhcp
    bridge_ports ens5f0
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
```

## User Modifications

```bash
sudo usermod -aG libvirt $USER
sudo vim /etc/libvirt/libvirtd.conf
```

In `/etc/libvirt/libvirtd.conf`:

```ini
unix_sock_group = "libvirt"
unix_sock_rw_perms = "0770"
auth_unix_ro = "none"
auth_unix_rw = "none"
```

```bash
sudo systemctl restart libvirtd

virsh net-autostart default
virsh net-start default
```

Reference:
[ArchWiki: PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)

## Passthrough

### CPU

```bash
sudo vim /etc/default/grub
GRUB_CMD_LINE_DEFAULT="... intel_iommu=on iommu=pt"
sudo grub-mkconfig -o /boot/grub/grub.cfg

cat /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTLABEL="PRIMARY" rootfstype=xfs add_efi_memmap intel_iommu=on iommu=pt rd.driver.pre=vfio-pci
#resume=PARTLABEL="SWAP" nomodeset i915.modeset=0
sudo mkinitcpio -P

dmesg | grep -i -e DMAR -e IOMMU
```

### GPU

```bash
# 查 id
lspci -nnk | grep -i NVIDIA -A3

cat /etc/modprobe.d/vfio.conf
options vfio-pci ids=10de:2204,10de:1aef

cat /etc/modules-load.d/modules.conf
vfio-pci

dmesg | grep -i vfio
```
