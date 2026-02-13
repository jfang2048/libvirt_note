# Virt-Install Examples

Environment-specific host/IP values in command examples should be treated as placeholders.

```shell
sudo virt-install \
--name fedora-compile \
--vcpus sockets=1,cores=24 \
--memory 24576 \
--disk /etc/libvirt/images/fedora-compile.raw,size=512,format=raw,bus=virtio \
--network network=default,model=virtio \
--cdrom /etc/libvirt/images/Fedora-Workstation-Live-x86_64-37-1.7.iso \
--video qxl \
--channel spicevmc \
--graphics spice,listen=0.0.0.0,port=5910,password=<SPICE_PASSWORD> \
--os-variant fedora37 \
--boot uefi
```

```shell
virt-install \
  --name jwang-test \
  --memory 16384 \
  --vcpus=8 \
  --disk /etc/libvirt/images/jwang-test.qcow2,size=80,format=qcow2,cache=none \
  --cdrom /etc/libvirt/images/debian-12.8.0-amd64-DVD-1.iso \
  --os-variant debian11 \
  --network bridge:vm-br0 \
  --video qxl \
  --channel spicevmc \
  --graphics spice,listen=0.0.0.0,password=<SPICE_PASSWORD> \
  --boot uefi
```
