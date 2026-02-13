# KVM VM Lifecycle And Operations

Environment-specific host/IP values in command examples should be treated as placeholders.

virsh help network | less

```bash
for vm in $(sudo virsh list --all --name); do     echo "$vm";     sudo virsh dumpxml "$vm" | grep -i "<source file" | sed -E 's/.*file='\''([^'\'']+)'\''.*/\1/';     echo "-------------------"; done

```


#### ballon
```bash
apt-get install qemu-guest-agent
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl status qemu-guest-agent
```

#### convert_img2qcow2
```bash
qemu-img convert -f raw -O qcow2 vm_hdd.img vm_hdd.qcow2
```

## base_image
```shell
# use case (base image + qcow2 overlay), the RAW format should be preferred
# https://serverfault.com/questions/677639/which-is-better-image-format-raw-or-qcow2-to-use-as-a-baseimage-for-other-vms

cd /var/lib/libvirt/images/
qemu-img create -f qcow2 base-image.qcow2 20G
virt-install ...

for i in {1..3}; do
    sudo qemu-img create -f qcow2 -b base-image.qcow2 -F qcow2 base-derive-$i.qcow2
done

# virsh edit base-image
virsh dumpxml base-image >  base-derive-1.xml
# or
cp base-image.xml  base-derive-1.xml

之后修改
base-derive-$i.xml
改 <name>
改 <source file ...
删 <uuid>
删 <mac address ...
------------
qemu-img create -f qcow2 -b /var/lib/libvirt/images/base-img-debian12.qcow2 -F qcow2 /var/lib/libvirt/images/CA-root.qcow2

virt-install \
--name CA-root \
--memory 2048 \
--vcpus=2 \
--disk path=/var/lib/libvirt/images/CA-root.qcow2,format=qcow2,cache=none \
--os-variant debian12 \
--network bridge:vm-br0 \
--video qxl \
--channel spicevmc \
--graphics spice,listen=0.0.0.0 \
--boot uefi

# --pxe \ if use ipxe to install
------------

qemu-system-x86_64  -hda  base-image-clone.qcow2  -m 2048

# Update XML file: name, disk path; remove mac address and uuid
sed -i \
    - e "s|<name>${source_name}</name>|<name>${target_name}</name>|" \
    - e "s|<source[^>]*file=\"[^\"]*\"|<source file=\"${target_qcow2}\"|" \
    - e "/<uuid>/d" \
    - e "/<mac address=/d" \
    "${target_xml}"
```

# snapshot

```bash
# In libvirt 10.9.0 both internal and external snapshots work with UEFI guest, as long as guest is using qcow2 backed nvram.
# If you have a VM that was created over 2 years ago, it may be using plain raw backed nvram, so you might need to reconfigure your VM.

# inner_sanpshot
virsh shutdown base-derive-1
virsh snapshot-create-as base-derive-1 \
    --name "base-derive-1-snapshot" \
    --description "Snapshot of base-derive-1 VM"

virsh snapshot-delete base-derive-1 --snapshotname "base-derive-1-snapshot"
# virsh snapshot-list wyang-desk
virsh snapshot-revert base-derive-1 --snapshotname "base-derive-1-snapshot"
# virsh snapshot-delete wyang-desk --snapshotname "wyang-desk-snapshot"
virsh start wyang-desk

# external_snapshot
virsh snapshot-create-as base-derive-1 \
    --name "base-derive-1-external-snapshot" \
    --description "External Snapshot of base-derive-1 VM" \
    --diskspec vda,file=/var/lib/libvirt/images/base-derive-1-external-snapshot.qcow2 \
    --disk-only \
    --atomic

virsh shutdown base-derive-1
virt-xml wyang-desk --edit target=vda --disk path=/path/to/external-snapshot.qcow2 --update
virsh start wyang-desk

# delete_snapshot
virsh snapshot-delete wyang-desk --snapshotname "wyang-desk-external-snapshot" --metadata
rm -rf /path/to/external-snapshot.qcow2
```
---

## install_VM

```shell
virt-install \
  --name preseedtest01 \
  --memory 2048 \
  --vcpus=2 \
  --disk /etc/libvirt/images/preseedtest01.qcow2,size=20,format=qcow2,cache=none \
  --cdrom /etc/libvirt/images/debian-12.8.0-amd64-DVD-1.iso \
  --os-variant debian11 \
  --network bridge:vm-br0 \
  --video qxl \
  --channel spicevmc \
  --graphics spice,listen=0.0.0.0,password=<SPICE_PASSWORD> \
  --boot uefi

# spice://192.0.2.102:5900
```

## post_install

```shell
sed -e "/^#PermitRootLogin/i PermitRootLogin yes" \
    - i /etc/ssh/sshd_config
systemctl restart sshd
systemctl restart networking

sed -i '/^deb cdrom/s/^/#/' /etc/apt/sources.list

cat > /etc/apt/sources.list <<EOF

deb https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
deb-src https://mirrors.aliyun.com/debian/ bookworm main non-free non-free-firmware contrib
deb https://mirrors.aliyun.com/debian-security/ bookworm-security main
deb-src https://mirrors.aliyun.com/debian-security/ bookworm-security main
deb https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
deb-src https://mirrors.aliyun.com/debian/ bookworm-updates main non-free non-free-firmware contrib
deb https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib
deb-src https://mirrors.aliyun.com/debian/ bookworm-backports main non-free non-free-firmware contrib
EOF

apt-get update

# deb http://mirrors.ustc.edu.cn/debian/ bookworm main non-free-firmware
# deb-src http://mirrors.ustc.edu.cn/debian/ bookworm main non-free-firmware
# deb http://mirrors.ustc.edu.cn/debian/ bookworm-updates main non-free-firmware
# deb-src http://mirrors.ustc.edu.cn/debian/ bookworm-updates main non-free-firmware

```

```bash
# network/interfaces 编辑

auto enp6s0
allow-hotplug enp6s0
iface enp6s0 inet manual

auto vm-br0
iface vm-br0 inet static
    address 192.0.2.103/24
    gateway 192.0.2.1
    dns-nameservers 192.0.2.35
    bridge_ports enp6s0
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
```

### migrate_VM

```bash
# scp /etc/libvirt/images/chrome-compile.qcow2 root-host:/etc/libvirt/images/
# or convert

virsh dumpxml chrome-compile > chrome-compile.xml
# use convert to other disk
# scp chrome-compile.xml root-host:/etc/libvirt/images/

virsh define /tmp/chrome-compile.xml
virsh start chrome-compile
```

### remove_VM

```shell
virsh destroy rsync-data
virsh undefine rsync-data --nvram
rm -f /etc/libvirt/images/rsync-data.qcow2

rm -f /var/log/libvirt/qemu/rsync-data.log
rm -f /var/log/swtpm/libvirt/qemu/rsync-data-swtpm.log
```

### mem_hotplug
```bash
qemu-system-aarch64 … –m 4G,slots=32,maxmem=32G

-m [size=]megs[,slots=n,maxmem=size]
                configure guest RAM
                size: initial amount of guest memory
                slots: number of hotplug slots (default: none)
                maxmem: maximum amount of guest memory (default: none)

<memory model=’dimm’>
<target>
<size unit=’KiB’>2097152</size>
<node>0</node>
</target>
</memory>

```
