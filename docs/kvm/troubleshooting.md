# KVM Troubleshooting

Environment-specific host/IP values in command examples should be treated as placeholders.

## resize_expand
```shell
apt update && apt reinstall cloud-utils parted -y

virsh blockresize unstable02 /var/lib/libvirt/images/unstable02.qcow2 100G

sudo apt update
sudo apt install -y cloud-guest-utils

# xfs_growfs /
# xfs_growfs /dev/vda2

#other_
swapoff -a
apt install parted
parted /dev/vda print
parted /dev/vda rm 2

growpart /dev/vda 3
resize2fs /dev/vda3
```

```bash
sudo qemu-img resize /var/lib/libvirt/images/debian11.qcow2 100G

sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 /var/lib/libvirt/images/debian11.qcow2  # 连接到NBD设备

sudo fdisk -l /dev/nbd0

sudo parted /dev/nbd0 resizepart 1 100%
sudo parted /dev/nbd0 print | grep "Disk /dev/nbd0"

sudo e2fsck -f /dev/nbd0p1
sudo resize2fs /dev/nbd0p1

sudo dumpe2fs -h /dev/nbd0p1 | grep "Block count"

sudo qemu-nbd -d /dev/nbd0
sudo rmmod nbd
```

```bash
swapoff -a
# umount releated partitions,please use fdisk -l /dev/vda
umount /dev/vda5 2>/dev/null
# delete some partitions
```

---


```bash
# find vm and kill
ps aux | grep zlan-test-env | grep -v grep | awk '{print $2}' | xargs sudo kill -9

# virsh命令卡死。。。莫名修复
sudo systemctl status virtqemud.service
sudo systemctl start virtqemud.service
sudo systemctl start libvirt
sudo systemctl status libvirtd
sudo systemctl restart libvirtd

# 迁移的qcow2记得改
sudo chown libvirt-qemu:libvirt-qemu some_vm.qcow2
```

##### netowrk_error
```bash
virsh net-start default
virsh net-autostart default

systemctl restart libvirtd
systemctl restart networking
```

##### uefi_boot
```bash
lsblk
fdisk -l /dev/vda  # adjust to EFI
mount /dev/vda1 /boot/efi
mount | grep /boot/efi
ls /boot/efi/EFI/debian/shimx64.efi
efibootmgr -c -d /dev/vda -p 1   -L "Debian Shim"   -l \\EFI\\debian\\shimx64.efi
```

##### disk_damage
```bash
qemu-img check /mnt/nfs-share/wyang-desk-copy-1.qcow2
qemu-img check -r all /mnt/nfs-share/wyang-desk-copy-1.qcow2

# other way
qemu-img convert -O qcow2 /mnt/nfs-share/wyang-desk-copy-1.qcow2 /mnt/nfs-share/wyang-desk-recovered.qcow2

# other
guestfish --rw -a /mnt/nfs-share/wyang-desk-copy-1.qcow2

# *maybe nfs mount error
sudo mount -t nfs -o vers=4.2,proto=tcp,rsize=65536,wsize=65536,timeo=600,retrans=2,hard,intr,noexec,nosuid,actimeo=0 nfs.example.internal:/mnt/shared_storage/mirrors /mnt/nfs-share

```

```shell
fs0:
\EFI\Debian\shimx64.efi # 进去后看输出的错误

# in other machine
rmmod nbd
modprobe nbd max_part=8
qemu-nbd -c /dev/nbd0 /mnt/pve/zfs-data-share/images/215/vm-215-disk-0.raw
fdisk -l /dev/nbd0
#  /dev/​​nbd0p1​​：EFI => /dev/vda1
#  ​/dev/nbd0p2​​：XFS filesystem=> /dev/vda2

xfs_repair -L -v /dev/nbd0p2 # 这里需要根据实际情况

for dev in {0..15}; do
    qemu-nbd -d /dev/nbd$dev 2>/dev/null
done

rmmod nbd
lsmod | grep nbd
```

##### root_passwd_reset
```bash

grub => e
ro quiet rw init=/bin/bash
ctrl+x

mount -o remount,rw /
mount | grep -w /

passwd root
exec /sbin/init

#rd.break
```

```bash
sudo cp debian-12-nocloud-amd64.qcow2 /var/lib/libvirt/images

sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 /var/lib/libvirt/images/debian-12-nocloud-amd64.qcow2
sudo mount /dev/nbd0p1 /mnt
sudo chroot /mnt/ /bin/bash -l

passwd root
exit

sudo umount /mnt
sudo qemu-nbd -d /dev/nbd0
sudo modprobe -r nbd

```
