# 服务器安装与 K8s 部署指南

本文档涵盖服务器全新安装、K8s 集群部署与 NixOS Anywhere 远程部署。

---

## 📦 服务器安装流程

### 1. 准备安装介质

**方式 A：使用官方 ISO**
从 [NixOS 官网](https://nixos.org/download/) 下载 ISO，放入 Ventoy U 盘启动。

**方式 B：使用自定义 ISO（推荐）**
```bash
# 在项目根目录构建自定义 ISO
nix build .#iso

# 将 ISO 复制到 Ventoy U 盘即可
cp result/iso/my-nixos-live.iso /mnt/ventoy/
```

> **Ventoy 使用方式：** 只需将 Ventoy 安装到 U 盘一次，之后直接将 ISO 文件拷贝到 U 盘中即可启动，无需重复写入。

### 2. 分区与挂载（全新安装）

服务器采用 `disk.nix` 进行声明式分区（**会清空磁盘**）：

```bash
sudo -i
# 确认磁盘设备名
lsblk

# 应用磁盘配置
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko .#server
```

### 3. 生成硬件配置

```bash
nixos-generate-config --root /mnt
```

⚠️ **重要：** 该命令会生成 `hardware-configuration.nix`，记录当前系统的文件系统 UUID 和内核模块。
请将生成的内容覆盖到 `hosts/server/hardware-configuration.nix`。

### 4. 同步配置文件

```bash
# 将整个配置目录复制到 /mnt/etc/nixos
cp -r /path/to/this/repo/Configuration/nixos/* /mnt/etc/nixos/
```

### 5. 安装系统

```bash
# 安装服务器（Nomad）
nixos-install --root /mnt --flake /mnt/etc/nixos#server

# 设置 root 密码
passwd

# 卸载并重启
umount -R /mnt
reboot
```

---

## 🌐 K8s 集群部署

### 架构：数据驱动（列表映射）

所有 K8s 节点通过 `config/nodes.nix` 定义，共用 `hosts/k8s-role.nix` 模板，由 `flake.nix` 自动映射生成：

```nix
# config/nodes.nix
{
  k8s-ctrl-01   = { ip = "192.168.1.11"; role = "control"; };
  k8s-worker-01 = { ip = "192.168.1.21"; role = "worker"; };
  k8s-combo-01  = { ip = "192.168.1.31"; role = "combo"; };
}
```

**新增机器只需在 `config/nodes.nix` 中加一行**，无需新建文件或修改 flake 结构。

### 节点角色

| 角色 | 说明 | 适用场景 |
|------|------|----------|
| `control` | 控制平面（apiserver + etcd + scheduler） | 控制节点 |
| `worker` | 工作节点（kubelet + kube-proxy） | 工作节点 |
| `combo` | 控制+工作合一 | 小集群/省资源 |

### 部署命令

```bash
# 部署控制节点
sudo nixos-rebuild switch --flake .#k8s-ctrl-01

# 部署工作节点
sudo nixos-rebuild switch --flake .#k8s-worker-01

# 部署组合节点（小集群）
sudo nixos-rebuild switch --flake .#k8s-combo-01
```

### 初始化集群

```bash
# 在第一个控制节点上初始化
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 配置 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 加入其他控制节点（控制平面）
kubeadm join <control-plane-ip>:6443 --control-plane --token <token> --discovery-token-ca-cert-hash <hash>

# 加入工作节点
kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### 实际使用提示

1. **修改 IP/角色**：编辑 `config/nodes.nix`，修改 IP 或调整角色（control/worker/combo）
2. **修改磁盘**：取消注释模板中的 `hardware-configuration.nix` 和 `disk.nix`（安装后生成）
3. **服务器默认**：`server` 主机默认使用 Nomad，K8s 使用独立节点配置

---

## 🌍 NixOS Anywhere 远程部署

NixOS Anywhere 允许你通过 SSH 将运行中的 Linux 系统（无论是否为 NixOS）替换为 NixOS。

### 场景一：服务器全新安装（推荐，全量格式化）
适用于新服务器或可以清空数据的机器。此方案最彻底、最自动化。

1. **准备 disko 配置**：在 flake 中定义磁盘分区，使用 `disko` 工具自动格式化。
2. **执行部署**：
   ```bash
   nix run github:nix-community/nixos-anywhere -- --flake .#your-host root@<IP>
   ```

### 场景二：现有系统迁移（保留数据分区）
适用于已有数据（如 `/home`, `/var`）且**有独立分区**的服务器。

⚠️ **风险警告**：默认情况下 NixOS Anywhere 会清空磁盘。要保留数据，必须在 `disko` 配置中**排除**数据分区，或仅对系统分区进行操作。

1. **配置策略**：
   * 在 `disko` 中**仅定义系统分区**（如 `/` 和 `/boot`）。
   * 在 `configuration.nix` 中通过 `fileSystems` 挂载现有的数据分区（不要通过 disko 格式化它们）。
   * **务必确认** `disko` 配置中没有包含数据分区的 `format` 操作。
2. **执行部署**：
   * 同场景一。

---

## ⚠️ 关键注意事项

### 密码设置风险 (`--no-root-passwd`)
* 使用 `nixos-install` 或 `nixos-anywhere` 时，如果添加了 `--no-root-passwd` 参数，Root 密码将为空。
* 如果你没有配置 SSH 公钥登录，重启后将**无法登录系统**。请务必确保配置中包含你的 SSH 公钥，或者在配置中设置了初始密码。

### 用户配置写法
* 推荐使用 `users.users.<name> = { ... };`。
* 在某些覆盖配置（Overlays）或 Home-Manager 集成场景下，可能会看到 `users.extraUsers.<name>` 的写法，两者在逻辑上等效，但 `extraUsers` 常用于模块化合并。请确保你的用户定义语法正确且 UID 保持一致。

### 硬件配置与分区

| 文件 | 用途 | 适用场景 |
|------|------|----------|
| `disk.nix` | 声明式磁盘分区（执行时会格式化） | 服务器 / 虚拟机 / 全新安装 |
| `hardware-configuration.nix` | 记录当前分区 UUID、挂载点、内核模块 | 所有主机 |

- `hardware-configuration.nix` 由 `nixos-generate-config` 自动生成，**不应手动编辑**。
- 安装新机器或更换硬件后，重新生成并覆盖对应文件。

---

## 📚 官方文档与参考资料

- [NixOS 官方手册](https://nixos.org/manual/nixos/stable/)
- [Flakes 文档](https://nixos.wiki/wiki/Flakes)
- [disko 文档](https://github.com/nix-community/disko)
- [NIXOS_LUSTRATE 说明](https://nixos.org/manual/nixos/stable/#sec-upgrading-notes)
- [nixos-install 说明](https://nixos.org/manual/nixos/stable/#sec-installation)