# Operator Notes

Environment-specific host/IP values in command examples should be treated as placeholders.

I ended up just passing it through to a vm directly, and then doing everything in containers, including gaming via sunshine and moonlight. Works decently.


pool volume
```bash
# Define a storage pool
virsh pool-define-as vm_pool dir --target /kvm/images
virsh pool-start vm_pool
virsh pool-autostart vm_pool

# Create a qcow2 volume
virsh vol-create-as vm_pool data_disk.qcow2 10G --format qcow2
virsh vol-list vm_pool  # Lists volumes in the pool
qemu-img info /kvm/images/data_disk.qcow2  # Checks disk details[13](@ref)

virsh attach-disk my_vm /kvm/images/data_disk.qcow2 vdb \
  --driver qemu --subdriver qcow2 --persistent

virsh vol-resize data_disk.qcow2 20G --pool vm_pool

# In the VM: Resize the filesystem (e.g., for Linux)
sudo growpart /dev/vdb 1  # Expand partition
sudo resize2fs /dev/vdb1  # Resize filesystem[9](@ref)


virsh vol-clone data_disk.qcow2 backup_disk.qcow2 --pool vm_pool
qemu-img convert -f raw -O qcow2 source.img disk.qcow2
```

migration
templates and snapshots


kimchi_webUI
LinuxBridge and Open vSwitch

oVirt

OpenStack

Tuning

v2v p2v migration tools


convert vm into hypervisor
