# KVM Performance Optimization

Environment-specific host/IP values in command examples should be treated as placeholders.

```bash

apt install -y tuned tuned-utils tuned-utils-systemtap
tuned-adm list
tuned-adm profile virtual-guest
```

```bash
for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
    echo performance | sudo tee $cpu/scaling_governor
done

for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
    echo "Core $(basename $(dirname $cpu)): $(cat $cpu/scaling_cur_freq) Hz"
done
```

```
      <feature enabled='no' name='enrolled-keys'/>
      <feature enabled='no' name='secure-boot'/>
```

### Optimize

#### mem

```bash
# KSM， 牺牲CPU换内存，适合多相似Guest的环境。
sudo systemctl enable ksmd
sudo systemctl start ksmd

echo 1 > /sys/kernel/mm/ksm/run
echo 1000 > /sys/kernel/mm/ksm/sleep_millisecs

# HugePages，牺牲内存灵活性换性能
# echo 1024 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
echo 1024 > /proc/sys/vm/nr_hugepages
# VM XML 中添加：
# <memoryBacking>
# <hugepages/>
# </memoryBacking>


# virtio-balloon ,底层机制
lsmod | grep virtio # vm guest

virsh dominfo debian-gitlab | grep memory
virsh dommemstat debian-gitlab
# virsh setmem debian-gitlab 12288MiB [--config | --live | --current]
virsh setmaxmem debian-gitlab 16777216 --currnt
virsh setmem debian-gitlab 12582912 --live
```

    KSM与HugePage：
        冲突：KSM合并小页可能破坏HugePage的连续性，需避免同时使用。
        建议：在高性能场景优先用HugePage，在高密度场景用KSM。

    KSM与Virt-Balloon：
        协同：KSM节省内存，Balloon回收内存，两者结合可最大化内存利用率。
        注意：Balloon收缩内存可能导致KSM合并页被拆分，降低效率。

    HugePage与Virt-Balloon：
        互补：HugePage提升性能，Balloon提供弹性，适合需要性能与灵活性兼顾的场景。
        限制：Balloon无法释放被HugePage占用的内存（需预留固定大页）。

###### resrict

```bash

# virsh memtune debian-gitlab
virsh memtune debian-gitlab --hard-limit 16777216 --soft-limit 12582912
# <memtune>
#   <hard_limit unit='KiB'>16777216</hard_limit>
# </memtune>
```
---
使得宿主机通过Unix socket文件与虚拟机内的QGA通信
```xml
<!-- 添加以下内容到<devices>标签内 -->
<channel type='unix'>
  <source mode='bind' path='/var/lib/libvirt/qemu/org.qemu.guest_ansible_test.0'/>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>

<memballoon model='virtio'>
  <alias name='balloon0'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
</memballoon>
```
guest:
    apt install qemu-guest-agent
    systemctl start qemu-guest-agent
    systemctl enable qemu-guest-agent
    systemctl status qemu-guest-agent
---

#### cpu

```bash
# lscpu | grep -E '^CPU$s$|Core|Socket|NUMA'
echo 'performance' | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance | sudo tee $cpu; done

# Intel cpu
cat /sys/devices/system/cpu/cpufreq/policy?/energy_performance_available_preferences
for policy in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do echo balance_performance | sudo tee $policy; done

# 分配内存到指定 NUMA 节点
# <numatune>
# <memory mode='strict' nodeset='0'/>  # 强制内存分配在 NUMA node0
# </numatune>

# vcpu pin ?
# <cputune>
# <vcpupin vcpu='0' cpuset='0'/>
# <vcpupin vcpu='1' cpuset='1'/>

# cgroup => cpu_resource restrict
```

---

#### Other

```bash
pgrep -f qemu-system  # Find the QEMU process ID (PID)
# set priority 99
# chrt -f -p 99 <QEMU_PID>
# perf 做监控
```


#### script

```shell
# virsh dominfo debian-gitlab | grep 'Max memory'
# virsh memtune debian-gitlab
# virsh dommemstat debian-gitlab


# get info
max_mem_restrict = $(virsh dominfo vm_tmp | grep Max memory)
mem_restrict = max_mem_restrict *3/4

# memtune
virsh memtune vm_tmp --hard-limit $max_mem_restrict --soft-limit $mem_restrict

# virtio-balloon
virsh setmaxmem vm_tmp $max_mem_restrict --current
virsh setmem vm_tmp $mem_restrict --live
```
