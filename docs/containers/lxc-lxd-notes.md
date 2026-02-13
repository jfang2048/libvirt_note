# LXC and LXD Notes

Environment-specific host/IP values in command examples should be treated as placeholders.

- Unprivileged containers use user namespaces.
- Container security relies on AppArmor, seccomp, and Linux namespaces.

## LXC

### Install and Create Container

```bash
sudo apt update
sudo apt install -y lxc debootstrap bridge-utils uidmap

# lxc-create -t download -n debian12-test -- --list | grep debian

sudo lxc-create -t download -n debian12-test -- \
  --dist debian \
  --release bookworm \
  --arch amd64

sudo lxc-ls -f
sudo lxc-attach -n debian12-test

echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null

# 接受 2222 端口的入站流量，并转发到容器
sudo iptables -t nat -A PREROUTING -i ens18 -p tcp --dport 2222 -j DNAT --to-destination 10.0.3.221:22

# 允许端口 2222 的入站流量
sudo iptables -A INPUT -p tcp --dport 2222 -j ACCEPT

# 配置 MASQUERADE（SNAT）用于容器返回流量
sudo iptables -t nat -A POSTROUTING -s 10.0.3.221 -o ens18 -j MASQUERADE

sudo apt update
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

# 删除规则
sudo iptables -t nat -D PREROUTING -i ens18 -p tcp --dport 2222 -j DNAT --to-destination 10.0.3.221:22
sudo iptables -D INPUT -p tcp --dport 2222 -j ACCEPT
sudo iptables -t nat -D POSTROUTING -s 10.0.3.221 -o ens18 -j MASQUERADE

# 怎么固定 IP
```

### Resource Restrict

```bash
# sudo vim /var/lib/lxc/debian12-test/config

lxc.cgroup2.memory.max = 1073741824

lxc.cgroup2.cpuset.cpus = 0,1
lxc.cgroup2.cpuset.cpus = 0-1

# Limit CPU usage to 50% (50000 out of 100000 microseconds)
lxc.cgroup2.cpu.max = 50000 100000

# Set CPU weight/priority (1-10000, default 100)
lxc.cgroup2.cpu.weight = 512

# disk_restrict，直接对文件夹限制，基于 quotas

lxc.uts.name = debian12-test
```

## LXD

*maybe incus is better*

### Install

```bash
apt install lxd
lxd init

sudo lxc remote list
sudo lxc remote set-url images https://images.lxd.canonical.com/
sudo lxc image list images:debian/bookworm

# sudo lxc profile edit default
# sudo lxc remote add tuna-images https://mirrors.tuna.tsinghua.edu.cn/lxc-images/ --protocol=simplestreams --public

sudo lxc launch images:debian/bookworm/amd64 test
sudo lxc exec test bash

# sudo lxc publish test --alias ubuntudemo --public

# sudo lxc config device add test proxy0 proxy listen=tcp:198.51.100.126:60601 connect=tcp:203.0.113.183:22 bind=host
```

### GPU

```bash
# notice_gpu_index
lxc config device add ubuntu22-tmp gpu-tmp gpu id=0
lxc config set ubuntu22-tmp security.nesting true
lxc config set ubuntu22-tmp security.privileged true

# lxc exec ubuntu22-tmp bash
```

#### Host GPU

*regular_way*

```bash
nvidia-smi -i 0 -mig 1  # 多显卡服务器按此方式开启，0 和 1 是显卡 ID
nvidia-smi -i 1 -mig 1
```

#### Guest GPU

```bash
bash ./NVIDIA-Linux-x86_64-550.90.07.run --no-kernel-module
```

#### LXD in Arch

```bash
sudo modprobe overlay
sudo modprobe veth
# sudo pacman -Syu lxd lxc
sudo systemctl start lxd
sudo systemctl enable lxd

sudo lxd init

lxc remote add debian https://cloud.debian.org/images/cloud/ --protocol simplestreams

mkdir -p ~/.config/lxc
cp /etc/lxc/default.conf ~/.config/lxc/default.conf

# lxc.idmap = u 0 100000 65536
# lxc.idmap = g 0 100000 65536
```

### Import `qcow2` to LXD

Use `security.csm=true` combined with `security.secureboot=false`. This enables SeaBIOS boot mode.
