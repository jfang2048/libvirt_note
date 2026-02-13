# KVM Performance Optimization

Environment-specific host/IP values in command examples should be treated as placeholders.

## Baseline Host Tuning

```bash
apt install -y tuned tuned-utils tuned-utils-systemtap
tuned-adm list
tuned-adm profile virtual-guest
```

```bash
for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
    echo performance | sudo tee "$cpu/scaling_governor"
done

for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
    echo "Core $(basename "$(dirname "$cpu")"): $(cat "$cpu/scaling_cur_freq") Hz"
done
```

### Firmware Feature Snippet

```xml
<feature enabled='no' name='enrolled-keys'/>
<feature enabled='no' name='secure-boot'/>
```

## Optimize

### Memory

```bash
# KSM，牺牲 CPU 换内存，适合多相似 Guest 的环境。
sudo systemctl enable ksmd
sudo systemctl start ksmd

echo 1 > /sys/kernel/mm/ksm/run
echo 1000 > /sys/kernel/mm/ksm/sleep_millisecs

# HugePages，牺牲内存灵活性换性能
# echo 1024 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
echo 1024 > /proc/sys/vm/nr_hugepages

# VM XML 中添加：
# <memoryBacking>
#   <hugepages/>
# </memoryBacking>

# virtio-balloon，底层机制
lsmod | grep virtio  # vm guest

virsh dominfo debian-gitlab | grep memory
virsh dommemstat debian-gitlab
# virsh setmem debian-gitlab 12288MiB [--config | --live | --current]
virsh setmaxmem debian-gitlab 16777216 --current
virsh setmem debian-gitlab 12582912 --live
```

KSM / HugePage / Virtio-Balloon 组合注意点：

- `KSM` 与 `HugePage`：
  - 冲突：KSM 合并小页可能破坏 HugePage 连续性，需避免同时使用。
  - 建议：高性能场景优先 HugePage，高密度场景优先 KSM。
- `KSM` 与 `Virt-Balloon`：
  - 协同：KSM 节省内存，Balloon 回收内存，可提高利用率。
  - 注意：Balloon 收缩内存可能导致 KSM 合并页拆分，降低效率。
- `HugePage` 与 `Virt-Balloon`：
  - 互补：HugePage 提升性能，Balloon 提供弹性。
  - 限制：Balloon 无法释放被 HugePage 占用的预留内存。

### Memory Restrict

```bash
# virsh memtune debian-gitlab
virsh memtune debian-gitlab --hard-limit 16777216 --soft-limit 12582912

# <memtune>
#   <hard_limit unit='KiB'>16777216</hard_limit>
# </memtune>
```

使得宿主机通过 Unix socket 文件与虚拟机内的 QGA 通信：

```xml
<!-- 添加以下内容到 <devices> 标签内 -->
<channel type='unix'>
  <source mode='bind' path='/var/lib/libvirt/qemu/org.qemu.guest_ansible_test.0'/>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>

<memballoon model='virtio'>
  <alias name='balloon0'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
</memballoon>
```

Guest:

```bash
apt install qemu-guest-agent
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent
systemctl status qemu-guest-agent
```

### CPU

```bash
# lscpu | grep -E '^CPU\(s\)$|Core|Socket|NUMA'
echo 'performance' | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance | sudo tee "$cpu"; done

# Intel CPU
cat /sys/devices/system/cpu/cpufreq/policy?/energy_performance_available_preferences
for policy in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do echo balance_performance | sudo tee "$policy"; done

# 分配内存到指定 NUMA 节点
# <numatune>
#   <memory mode='strict' nodeset='0'/>  # 强制内存分配在 NUMA node0
# </numatune>

# vCPU pin
# <cputune>
#   <vcpupin vcpu='0' cpuset='0'/>
#   <vcpupin vcpu='1' cpuset='1'/>
# </cputune>

# cgroup => cpu_resource restrict
```

### Other

```bash
pgrep -f qemu-system  # Find the QEMU process ID (PID)
# set priority 99
# chrt -f -p 99 <QEMU_PID>
# perf 做监控
```

### Script Notes

```bash
# virsh dominfo debian-gitlab | grep 'Max memory'
# virsh memtune debian-gitlab
# virsh dommemstat debian-gitlab

# get info
max_mem_restrict=$(virsh dominfo vm_tmp | awk -F': *' '/Max memory/ {print $2}' | awk '{print $1}')
mem_restrict=$((max_mem_restrict * 3 / 4))

# memtune
virsh memtune vm_tmp --hard-limit "$max_mem_restrict" --soft-limit "$mem_restrict"

# virtio-balloon
virsh setmaxmem vm_tmp "$max_mem_restrict" --current
virsh setmem vm_tmp "$mem_restrict" --live
```
