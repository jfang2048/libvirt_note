# Proxmox Operations

Environment-specific host/IP values in command examples should be treated as placeholders.

#### nfs_bug_fix
sudo systemctl restart rpcbind
sudo systemctl restart nfs-client.target
sudo systemctl status rpcbind nfs-client.target
sudo mkdir -p /mnt/pve/zfs-data-share
sudo umount -l /mnt/pve/zfs-data-share 2>/dev/null
sudo mount -t nfs -o rw,hard,intr,timeo=5,retry=5 198.51.100.120:/data/share/pve/pve_data /mnt/pve/zfs-data-share





#### some_command
```bash
qm list
qm guest exec 217 -- ip -4 -br address

```
磁盘格式从IDEA改为SCSI

## passthrough

### config
```shell
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt rd.driver.pre=vfio-pci"

proxmox-boot-tool refresh  # instead update-grub

cat >> /etc/modules <<EOF
vfio
vfio_iommu_type1
vfio_pci
# vfio_virqfd
EOF

# TEST
dmesg | grep -e DMAR -e IOMMU
dmesg | grep remappin

cat >> /etc/modprobe.d/pve-blacklist.conf <<EOF
blacklist nvidiafb
blacklist nouveau
blacklist nvidia
EOF

cat >> /etc/modprobe.d/kvm.conf <<EOF
options kvm ignore_msrs=1 report_ignored_msrs=0
EOF

update-initramfs -u
```
### load_gpu

*disable secure boot and custom*
raw -> add pci
*donot select main gpu*

ref[https://www.cnblogs.com/MAENESA/p/18005241]

*windows gpu不勾选 All Functions, Primary GPU,勾选 ROM-Bar, PCI-Express*
建议使用win10 bios q35 vIOMMU, 否则要 ROM vBIOS
win11使用bios有点问题，必须UEFI，Enable the All Functions, ROM-Bar, and PCI-Express options, let the Primary GPU setting remain disabled

RDP调用GPU,需要使用 勾选，Primary GPU


*linux gpu  不勾选 PCI-Express, Primary GPU,  勾选ROM-Bar, All Functions*

---

## storage

qm importdisk 100 /mnt/ZFS/qcow2_bak/preunstable.qcow2 zfs-data-share

	export /data/share/pve-backend
	path /mnt/pve/zfs-data-share

198.51.100.155:/data/share/pve-backend   19T  1.2T   17T   7% /mnt/pve/zfs-data-share
198.51.100.155:/data/share/              19T  1.2T   17T   7% /mnt/ZFS



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
qm importdisk 100 /var/lib/vz/qcow2/jbq-dev.qcow2 local-lvm --format qcow2

#### remount
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
#### repair
```bash
lvs -a -o+thin_count,data_percent,metadata_percent myvg/thinpool #查看存储

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

## shutdown
```bash
mv /var/lock/qemu-server/lock-111.conf /var/lock/qemu-server/lock-111.conf.bak
qm stop 111 --skiplock 1
```











































---

## misc

proxmox-auto-install-assistant prepare-iso /path/proxmox-ve_8.3-1.iso --fetch-from iso --answer-file /path/proxmox-ve_qykj.toml


```
    新建一个虚拟机，配置与原虚拟机基本一致，硬盘大小使用缺省，记下虚拟机ID
    登录PVE主机在命令行导入qcow2文件：”qm importdisk 100 /mnt/nvme0n1p1/images/100/vm-100-disk-0.qcow2 local″，其中”100″为虚拟机ID，”local″为导入到的目标存储
    导入后在网页端”虚拟机->硬件”页面删除创建虚拟机时的缺省硬盘，并启用导入的虚拟机硬盘(双击导入的硬盘，并选择确认”
    在网页端”虚拟机->选项”里面调整启动顺序，将导入的虚拟机硬盘的启动优先级调到最前面(硬盘前面没有打勾的要打勾,如果控制器是scis的,不打勾则在虚拟机BIOS里找不到磁盘,实测控制器IDE不打勾也可以找到,但默认的seaBIOS只有一个选择当前从哪个设备启动的功能,顺序只能从pve网页管理界面调)
```

机器类型决定了虚拟机主板的硬件布局，具体有Intel 440FX和Q35两种可选。Q35提供了虚拟PCIe总线，是进行PCIe直通的必备之选。*

如果你想追求最极致的性能，可以选用VirtIO SCSI single，并启用IO Thread选项。在选用VirtIO SCSI single时，Qemu将为每个虚拟磁盘创建一个专用控制器，而不是让所有磁盘共享一个控制器

​格式	    性能	 空间占用    	快照	     压缩	    加密  	跨平台兼容性
​Raw	    极高	 100%	    不支持	 不支持	    不支持	通用（可直接挂载）
​Qcow2	高	 动态分配	    支持	     支持	    支持   	QEMU/KVM 最佳

IO Thread => 当使用VirtIO SCSI single控制器时，对于启用Virtio控制器或Virtio SCSI控制器时的磁盘可以启用IO Thread。启用IO Thread后，Qemu将为每一个虚拟硬盘分配一个读写线程，与之前所有虚拟硬盘共享一个线程相比，能大大提高多硬盘虚拟机的性能。注意，IO Thread配置并不能提高虚拟机备份的速度。

cpulimit,cpuunits

    intel cpu => pcid,spec-ctrl,ssbd
    amd cpu => ibpd, virt-ssbd, amd-ssbd

```bash
# intel archlinux boot_loader=systemd-boot
grep  'pcid'  /proc/cpuinfo

/boot/loader/entries/arch.conf

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

此外还可以选择在虚拟机上启用NUMA架构模拟功能。NUMA架构的基本设计是，抛弃了以往多个内核共同使用一个大内存池的设计，而将内存按照Socket分配个每个CPU插槽。NUMA能有效解决共用一个大内存池时的内存总线瓶颈问题，大大改善系统性能。如果你的物理服务器支持NUMA架构，我们推荐启用该配置，从而更合理地在物理服务器上分配虚拟机工作负载。此外，如果要使用虚拟机的CPU和内存热插拔，也需要启用该项配置。

如果启用了`NUMA`，建议为虚拟机分配和物理服务器一致的Socket数量。

启用Multiqueue可以让虚拟机同时使用多个虚拟CPU处理网络数据包，从而提高整体网络数据包处理能力。推荐设置虚拟机收发队列数量和虚拟CPU数量一致。此外，还需要为每个虚拟VirtIO网卡设置多功能通道数量，命令如下：`ethtool -L eth0 combined X`其中X指虚拟机的虚拟CPU数量。
需要注意，当设置multiqueue参数值大于1时，网络流量增大会引发主机CPU和虚拟机CPU负载的升高。我们推荐仅在虚拟机需要处理大量网络数据包时启用该配置，例如用作路由器、反向代理或高负载HTTP服务器时。

qxl 半虚拟化，Linux虚拟机默认可以拥有多个虚拟显示器，选择启用多显示器模式时，会根据显示器数量自动为显卡分配多份显存。 选择使用serialX类型显卡时，会自动禁用VGA输出，并将Web控制台输出重定向到指定的串口。此时memory参数设置将不再生效。

VirtIO RNG,虚拟硬件-RNG可用于将这种熵从主机系统提供给客户VM。这有助于避免来宾中出现熵匮乏问题(没有足够的熵可用，系统可能会变慢或遇到问题)，特别是在来宾引导过程中。

https://pve-doc-cn.readthedocs.io/zh-cn/latest/chapter_virtual_machines/pcipassthrough.html
SR-IOV，SR-IOV（Single-Root Input/Output Virtualization）技术可以支持硬件同时提供多个VF（Virtual Function）供系统使用。

/etc/pve/qemu-server/<VMID>.conf
/etc/pve/lxc/<CTID>.conf
/etc/vzdump.conf

pveam pct vzdump

https://pve-doc-cn.readthedocs.io/zh-cn/latest/chapter_user_management/Authentication_Realms.html#ldap


也可以调度方式执行备份操作，以便在指定的日期和时间自动备份指定节点上的虚拟机。配置的调度任务会自动保存到 `/etc/pve/jobs.cfg`文件中，该文件会被`pvescheduler`守护程序读取并执行。 备份作业由日历事件来定义计划


Ballooning
qemu-guest-agent
    apt install qemu-guest-agent
    systemctl start qemu-guest-agent
    systemctl enable qemu-guest-agent
