# Proxmox Operations

Environment-specific host/IP values in command examples should be treated as placeholders.

## NFS Bug Fix

```bash
sudo systemctl restart rpcbind
sudo systemctl restart nfs-client.target
sudo systemctl status rpcbind nfs-client.target
sudo mkdir -p /mnt/pve/zfs-data-share
sudo umount -l /mnt/pve/zfs-data-share 2>/dev/null
sudo mount -t nfs -o rw,hard,intr,timeo=5,retry=5 198.51.100.120:/data/share/pve/pve_data /mnt/pve/zfs-data-share
```

## Utility Commands

```bash
qm list
qm guest exec 217 -- ip -4 -br address
```

磁盘格式从 IDEA 改为 SCSI。

## Passthrough

### Config

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt rd.driver.pre=vfio-pci"

proxmox-boot-tool refresh  # instead of update-grub

cat >> /etc/modules <<'EOF_MODULES'
vfio
vfio_iommu_type1
vfio_pci
# vfio_virqfd
EOF_MODULES

# TEST
dmesg | grep -e DMAR -e IOMMU
dmesg | grep remappin

cat >> /etc/modprobe.d/pve-blacklist.conf <<'EOF_BLACKLIST'
blacklist nvidiafb
blacklist nouveau
blacklist nvidia
EOF_BLACKLIST

cat >> /etc/modprobe.d/kvm.conf <<'EOF_KVM'
options kvm ignore_msrs=1 report_ignored_msrs=0
EOF_KVM

update-initramfs -u
```

### Load GPU

- disable secure boot and custom
- raw -> add pci
- donot select main gpu
- Reference: [cnblogs MAENESA](https://www.cnblogs.com/MAENESA/p/18005241)
- windows gpu 不勾选 `All Functions`, `Primary GPU`；勾选 `ROM-Bar`, `PCI-Express`
- 建议使用 win10 bios q35 vIOMMU，否则要 ROM vBIOS
- win11 使用 BIOS 有点问题，必须 UEFI；Enable the `All Functions`, `ROM-Bar`, and `PCI-Express` options，`Primary GPU` 保持禁用
- RDP 调用 GPU 需要勾选 `Primary GPU`
- linux gpu 不勾选 `PCI-Express`, `Primary GPU`，勾选 `ROM-Bar`, `All Functions`

## Storage

```bash
qm importdisk 100 /mnt/ZFS/qcow2_bak/preunstable.qcow2 zfs-data-share
```

```text
export /data/share/pve-backend
path /mnt/pve/zfs-data-share

198.51.100.155:/data/share/pve-backend   19T  1.2T   17T   7% /mnt/pve/zfs-data-share
198.51.100.155:/data/share/              19T  1.2T   17T   7% /mnt/ZFS
```

```bash
mount -t nfs -c 198.51.100.155:/data/share/ /mnt/ZFS

lvcreate --type thin-pool -Zn -l 100%FREE --chunksize 512K -n thinpool myvg
blockdev --getsize64 /dev/loop0
vim /etc/pve/storage.cfg

lvmthin: local-lvm-thin
    vgname myvg
    thinpool thinpool
    content images,rootdir
    shared 0

pvesm status local-lvm-thin
# lvextend -L +20G /dev/myvg/thinpool  # 示例扩容 20G

# in other node
losetup -f /mnt/ZFS/pve-lvm/thinpool.img
vgscan
```

```bash
qm importdisk 100 /var/lib/vz/qcow2/jbq-dev.qcow2 local-lvm --format qcow2
```

### Remount

```bash
mount -t nfs -c 198.51.100.155:/data/share/ /mnt/ZFS

losetup -D
losetup -f /mnt/ZFS/pve-lvm/thinpool.img
losetup -a

vgchange -an myvg
pvscan --cache -v
vgscan --mknodes
vgchange -ay myvg
```

### Repair

```bash
lvs -a -o+thin_count,data_percent,metadata_percent myvg/thinpool  # 查看存储

lvchange -an myvg/thinpool
lvconvert --repair myvg/thinpool

lvchange -ay myvg/thinpool
lvchange --refresh myvg/thinpool

# activate
lvchange -ay myvg/vm-100-disk-0
lvchange -ay myvg/vm-100-disk-1
lvchange -ay myvg/vm-203-disk-1
lvchange -ay myvg/vm-205-disk-0
```

## Shutdown

```bash
mv /var/lock/qemu-server/lock-111.conf /var/lock/qemu-server/lock-111.conf.bak
qm stop 111 --skiplock 1
```

## Misc

```bash
proxmox-auto-install-assistant prepare-iso /path/proxmox-ve_8.3-1.iso --fetch-from iso --answer-file /path/proxmox-ve_qykj.toml
```

```text
新建一个虚拟机，配置与原虚拟机基本一致，硬盘大小使用缺省，记下虚拟机 ID
登录 PVE 主机在命令行导入 qcow2 文件：qm importdisk 100 /mnt/nvme0n1p1/images/100/vm-100-disk-0.qcow2 local（100 为虚拟机 ID，local 为目标存储）
导入后在网页端“虚拟机 -> 硬件”页面删除创建虚拟机时的缺省硬盘，并启用导入的虚拟机硬盘（双击导入的硬盘并确认）
在网页端“虚拟机 -> 选项”里调整启动顺序，将导入硬盘优先级调到最前；硬盘前面没有打勾的要打勾
如果控制器是 scsi，不打勾则在虚拟机 BIOS 找不到磁盘；实测 IDE 控制器不打勾也可找到，但默认 SeaBIOS 只能选择当前启动设备，顺序建议从 PVE 网页管理界面调整
```

机器类型决定了虚拟机主板硬件布局，常见有 Intel 440FX 和 Q35。Q35 提供虚拟 PCIe 总线，是 PCIe 直通常见选择。

如果追求极致性能，可选 `VirtIO SCSI single` 并启用 `IO Thread`。该模式会给每块虚拟磁盘创建专用控制器，而不是共享一个控制器。

### Raw vs Qcow2

| 格式 | 性能 | 空间占用 | 快照 | 压缩 | 加密 | 跨平台兼容性 |
| --- | --- | --- | --- | --- | --- | --- |
| Raw | 极高 | 100% | 不支持 | 不支持 | 不支持 | 通用（可直接挂载） |
| Qcow2 | 高 | 动态分配 | 支持 | 支持 | 支持 | QEMU/KVM 最佳 |

`IO Thread` 说明：当使用 `VirtIO SCSI single`，对 VirtIO 磁盘启用 `IO Thread` 后，QEMU 可为每块虚拟硬盘分配独立读写线程；相比全部磁盘共享线程，多盘负载时性能通常更好。注意：`IO Thread` 不会提升虚拟机备份速度。

`cpulimit`, `cpuunits`。

- intel cpu => `pcid`, `spec-ctrl`, `ssbd`
- amd cpu => `ibpd`, `virt-ssbd`, `amd-ssbd`

```bash
# intel archlinux boot_loader=systemd-boot
grep 'pcid' /proc/cpuinfo

# /boot/loader/entries/arch.conf
options root=PARTLABEL="PRIMARY" rootfstype=xfs add_efi_memmap intel_iommu=on iommu=pt rd.driver.pre=vfio-pci pcid
```

```bash
# amd debian12 boot_loader=grub
vim /etc/default/grub

GRUB_CMDLINE_LINUX="spectre_v2=on ssbd=force-enable"
cat /proc/cmdline | grep -E "spectre|ssbd"
dmesg | grep -i "IBPB\|SSBD\|spec_store_bypass"

# 确保安装最新微码包（如 amd64-microcode）和 Linux 6.1+ 内核
```

此外可以启用虚拟机 `NUMA` 架构模拟。NUMA 将内存按 Socket 分配给 CPU 插槽，可缓解共享大内存池导致的总线瓶颈。如果物理服务器支持 NUMA，通常建议启用。若要使用 CPU/内存热插拔，也需要启用该项配置。

如果启用了 `NUMA`，建议为虚拟机分配与物理服务器一致的 Socket 数量。

启用 `Multiqueue` 可让虚拟机并行使用多个 vCPU 处理网络包，推荐队列数与 vCPU 数一致。还需为每个 VirtIO 网卡设置多队列通道：`ethtool -L eth0 combined X`（`X` 为 vCPU 数量）。

注意：`multiqueue > 1` 时，流量变大可能提高主机和虚拟机 CPU 负载，适合路由器、反向代理或高负载 HTTP 场景。

`qxl` 半虚拟化：Linux 虚拟机可使用多显示器；启用多显示器模式会按显示器数量分配显存。选择 `serialX` 类型显卡会禁用 VGA 输出并将 Web 控制台重定向到串口，此时 `memory` 参数不生效。

`VirtIO RNG`：可将宿主机熵源提供给客户机，减少来宾熵不足导致的变慢或异常，尤其在引导阶段。

References:

- <https://pve-doc-cn.readthedocs.io/zh-cn/latest/chapter_virtual_machines/pcipassthrough.html>
- SR-IOV：SR-IOV（Single-Root Input/Output Virtualization）支持硬件同时提供多个 VF（Virtual Function）。
- `/etc/pve/qemu-server/<VMID>.conf`
- `/etc/pve/lxc/<CTID>.conf`
- `/etc/vzdump.conf`
- `pveam`, `pct`, `vzdump`
- <https://pve-doc-cn.readthedocs.io/zh-cn/latest/chapter_user_management/Authentication_Realms.html#ldap>

也可以按调度方式执行备份，以便在指定日期和时间自动备份指定节点上的虚拟机。调度任务会保存到 `/etc/pve/jobs.cfg`，由 `pvescheduler` 守护进程读取并执行。备份作业通过日历事件定义计划。

Ballooning / `qemu-guest-agent`：

```bash
apt install qemu-guest-agent
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
```
