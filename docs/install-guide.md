# NixOS 安装指南

本文档为 NixOS 安装与部署的统一指南，涵盖**服务器**、**工作站**、**K8s 集群**、**远程部署**以及**从第三方系统迁移**等所有场景。

文档结构：先介绍适用于所有场景的**通用安装流程**，再针对不同场景展开具体操作说明。

---

## 一、通用安装流程

无论目标机器是服务器还是工作站，无论采用何种安装介质，核心步骤均遵循以下流程：

```
准备安装环境 → 克隆配置仓库 → 确认目标磁盘 → 分区与挂载 → 生成硬件配置 → 同步配置文件 → 执行安装 → 设置密码 → 重启
```

### 1. 准备安装环境

有三种方式可以获取 NixOS 安装工具链：

| 方式 | 适用情况 | 说明 |
|------|----------|------|
| **官方 ISO** | 快速体验/标准安装 | 从 [NixOS 官网](https://nixos.org/download/) 下载 ISO，放入 Ventoy U 盘启动 |
| **Portable 自定义 ISO（推荐）** | 包含完整工具链与离线缓存 | 使用 `nix build .#portable` 构建便携系统盘，支持本地优先安装 |
| **从非 NixOS 系统安装** | 宿主机已有 Linux 且不想制作 U 盘 | 在宿主机安装 Nix 包管理器后获取安装工具 |

> **Ventoy 使用方式：** 只需将 Ventoy 安装到 U 盘一次，之后直接将 ISO 文件拷贝到 U 盘中即可启动，无需重复写入。

### 2. 克隆配置仓库

```bash
git clone <你的仓库地址> ~/nixos-config
cd ~/nixos-config
```

> 若使用官方 ISO 或 Live 环境，配置目录可能已自动挂载；Portable 系统则需要手动克隆。

### 3. 确认目标磁盘

```bash
lsblk -f
```

常见设备名：
- `/dev/nvme0n1` — 内置 NVMe 固态硬盘
- `/dev/sda`     — SATA 硬盘
- `/dev/sdb`     — 你的 USB 系统盘（**请勿选错！**）

请根据容量确认目标硬盘，下文以 `/dev/nvme0n1` 为例。

### 4. 分区与挂载

根据是否可清空磁盘，选择以下两种方案之一：

#### 方案 A：使用 disko 分区（全新安装，会清空磁盘）

本项目已集成 [disko](https://github.com/nix-community/disko)，可一键完成分区、格式化和挂载。

```bash
# 格式化并自动挂载到 /mnt
sudo nix run github:nix-community/disko -- --mode disko ./hosts/<目标主机>/disk.nix
```

> **💡 提示：安装中断后恢复**
> 若已分好区但安装中途暂停，下次继续时无需重新格式化，改用 `mount` 模式仅挂载：
> ```bash
> sudo nix run github:nix-community/disko -- --mode mount ./hosts/<目标主机>/disk.nix
> ```

#### 方案 B：保留现有分区（使用 disko）

适用于已有数据和独立分区的场景。通过配置 disko 的 `noFormat`（或新版本 `_create = false`）选项，disko 将仅挂载现有分区而不会格式化数据。

1. 确保 `./hosts/<目标主机>/disk.nix` 配置正确（匹配现有分区结构且不破坏数据）。
2. 执行挂载：
   ```bash
   sudo nix run github:nix-community/disko -- --mode mount ./hosts/<目标主机>/disk.nix
   ```

### 5. 生成硬件配置

```bash
nixos-generate-config --root /mnt
```

该命令会自动扫描 `/mnt` 下的分区 UUID 并生成 `hardware-configuration.nix`，记录当前系统的文件系统 UUID 和内核模块。

请将生成的内容覆盖到对应主机的配置文件中（如 `hosts/server/hardware-configuration.nix` 或 `hosts/workstation/hardware-configuration.nix`）。

### 6. 同步配置文件

```bash
# 将整个配置目录复制到 /mnt/etc/nixos
sudo cp -r /path/to/this/repo/Configuration/nixos/* /mnt/etc/nixos/
```

> 若已在配置仓库目录下操作，可直接 `sudo cp -r ./* /mnt/etc/nixos/`。

### 7. 执行安装（含离线缓存选项）

Portable ISO 通过 `cache.nix` 预置了大量包，安装时可优先使用本地缓存，避免重复下载。

| 模式 | 命令参数 | 说明 |
|---|---|---|
| **纯离线** | `--option substitute false` | 仅使用本地 `/nix/store` 中的包，缺失则报错 |
| **本地优先** | `--option substituters "file:///nix/store https://cache.nixos.org"` | 本地缺失时自动回退网络下载 |
| **默认** | 无额外参数 | 直接联网下载（可能重复拉取已有包） |

> **⚠️ 注意**：`--no-substitute` 参数在较新版本中已废弃，请使用 `--option substitute false` 替代。

```bash
# 示例：本地优先 + 国内镜像兜底
sudo nixos-install --root /mnt --flake /mnt/etc/nixos#workstation \
  --option substituters "file:///nix/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org" \
  --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
```

> **💡 提示：sudo 路径**
> NixOS 中 `sudo` 的实际路径为 `/run/wrappers/bin/sudo`。若环境中直接输入 `sudo` 提示 `command not found`，请使用完整路径或执行 `export PATH="/run/wrappers/bin:$PATH"`。

### 8. 设置密码 & 重启

```bash
# 设置用户密码
sudo nixos-enter --root /mnt --command "passwd master"

# 或设置 root 密码（如未配置 SSH 公钥登录）
sudo passwd

# 卸载并重启
sudo umount -R /mnt
reboot
```

重启后从 BIOS/UEFI 选择目标硬盘启动，验证系统是否正常。

---

## 二、场景特定安装

### 2.1 服务器安装 (Server)

服务器通常采用声明式磁盘配置，安装时指定 `#server` flake：

```bash
# 1. 应用 disko 分区（会清空磁盘）
sudo nix run github:nix-community/disko -- --mode disko ./hosts/server/disk.nix

# 2. 生成硬件配置
nixos-generate-config --root /mnt
# 将生成内容覆盖到 hosts/server/hardware-configuration.nix

# 3. 同步配置并安装
sudo cp -r ./Configuration/nixos/* /mnt/etc/nixos/
sudo nixos-install --root /mnt --flake /mnt/etc/nixos#server

# 4. 设置密码 & 重启
sudo nixos-enter --root /mnt --command "passwd master"
sudo umount -R /mnt
reboot
```

> 服务器主机现作为 K8s 节点使用（支持 control/worker/combo 角色），Nomad 模块已废弃并移除。

---

### 2.2 工作站安装 (Workstation)

工作站提供两种安装方式，根据是否有独立数据分区选择：

#### 方式 A：保留现有分区（推荐）

适用于已有分区和数据的工作站。

1. **挂载分区**：参考 [方案 B](#方案-b保留现有分区使用-disko)，使用 disko 仅挂载模式：
   ```bash
   sudo nix run github:nix-community/disko -- --mode mount ./hosts/workstation/disk.nix
   ```
2. **生成硬件配置**：
   ```bash
   nixos-generate-config --root /mnt
   # 将生成内容覆盖到 hosts/workstation/hardware-configuration.nix
   ```
3. **安装**：后续步骤同通用流程（安装、设置密码等）。

#### 方式 B：全新安装（清空磁盘）

```bash
sudo nix run github:nix-community/disko -- --mode disko ./hosts/workstation/disk.nix
# 后续步骤同通用流程第 5~8 步，安装目标使用 #workstation
```

#### 桌面环境说明

工作站默认配置了 **COSMIC Desktop Environment** 及相关工具链：

| 类别 | 内容 |
|------|------|
| **桌面环境** | COSMIC DE (System76 新一代桌面) |
| **输入法** | fcitx5 + 中文支持 |
| **字体** | Noto Sans CJK、Source Han Sans 等 |
| **核心应用** | Ghostty 终端、Zed 编辑器、浏览器、媒体播放器 |
| **开发工具** | Rust、Haskell、Bun、Python、WASM、C/C++ 工具链 |
| **通讯工具** | 微信 (wechat-uos) |
| **办公套件** | WPS Office、Zathura PDF 阅读器 |

COSMIC 桌面启动后即可使用，所有开发工具已随系统安装，无需额外配置。

#### Home Manager 配置

用户级配置（dotfiles、GUI 应用设置）通过 Home Manager 管理，位于 `modules/home/workstation/`。主要模块包括：
- `shell.nix` — Nushell 配置
- `editors.nix` — Helix/Neovim/Zed 配置
- `terminals.nix` — Ghostty + Zellij 配置
- `git.nix` — Git + lazygit + delta 配置
- `xdg.nix` — XDG 目录关联

更新 Home Manager 配置：
```bash
sudo nixos-rebuild switch --flake .#workstation
```

---

### 2.3 K8s 集群部署

#### 架构：集群级配置 + 数据驱动

所有 K8s 节点通过 `config/nodes/` 下的集群文件定义，每个集群文件返回 `{ runtime; nodes; }` 结构：
- `runtime` - 集群级容器运行时（`crio` 或 `containerd`），该集群所有节点共享
- `nodes` - 节点定义 attrset，每个节点包含 `hostname`、`ip`、`role`、`imports`

```nix
# config/nodes/large-cluster.nix
{
  runtime = "containerd";
  nodes = {
    k8s-ctrl-01 = { hostname = "k8s-ctrl-01"; ip = "192.168.1.11"; role = "control"; imports = []; };
    k8s-ctrl-02 = { hostname = "k8s-ctrl-02"; ip = "192.168.1.12"; role = "control"; imports = []; };
    k8s-worker-01 = { hostname = "k8s-worker-01"; ip = "192.168.1.21"; role = "worker"; imports = []; };
  };
}
```

> `masterIP` 由 `flake.nix` **自动注入**：首个 control 节点作为 master，其余节点自动指向它。

`flake.nix` 自动展平所有集群并添加集群前缀，生成 `集群__节点` 格式的节点名，避免跨集群同名冲突。

**新增机器只需在对应集群文件中加一行**，无需修改 flake 结构。

#### 节点角色

| 角色 | 说明 | 适用场景 |
|------|------|----------|
| `control` | 控制平面（apiserver + etcd + scheduler） | 控制节点 |
| `worker` | 工作节点（kubelet + kube-proxy） | 工作节点 |
| `combo` | 控制+工作合一 | 小集群/省资源 |

#### 部署命令

```bash
# 部署组合节点（小集群）
sudo nixos-rebuild switch --flake .#smallCluster__k8s-combo-01 --target-host root@192.168.1.31

# 部署控制节点（大集群）
sudo nixos-rebuild switch --flake .#largeCluster__k8s-ctrl-01 --target-host root@192.168.1.11

# 部署开发服务器
sudo nixos-rebuild switch --flake .#dev__dxserver --target-host root@172.178.5.123
```

> 节点名格式：`集群__节点`（双下划线分隔），例如 `smallCluster__k8s-combo-01`、`dev__dxserver`。

#### 运行时选择

运行时是**集群级配置**，同一集群的所有节点必须使用相同的容器运行时：
- `crio` — CRI-O + podman（支持 `podman load` 导入镜像）
- `containerd` — Containerd + nerdctl（podman 被禁用）

在集群文件中修改 `runtime` 字段即可切换。

#### 初始化集群

NixOS 的 `services.kubernetes.roles` 模块**自动处理** kubeadm init 和 join：
- 首个控制节点部署时，自动执行 `kubeadm init`
- 其他控制节点/工作节点部署时，自动执行 `kubeadm join`

#### 获取 kubeconfig

部署完成后，使用 `scripts/inline-kubeconfig.nu` 生成 kubeconfig（自动读取系统证书，生成内联 base64 配置）：

```bash
# 在控制节点上生成 kubeconfig
nu scripts/inline-kubeconfig.nu "https://<控制节点IP>:6443" | save ~/.kube/config

# 或本地访问（默认 127.0.0.1:6443）
nu scripts/inline-kubeconfig.nu | save ~/.kube/config

# 验证
kubectl get nodes
```

#### 实际使用提示

1. **修改 IP/角色**：编辑 `config/nodes/<集群>.nix`，修改 IP 或调整角色
2. **修改磁盘**：取消注释模板中的 `hardware-configuration.nix` 和 `disk.nix`（安装后生成）
3. **新增集群**：在 `config/nodes/` 下新建文件，并在 `config/nodes.nix` 的 `clusters` 中添加引用

---

### 2.4 NixOS Anywhere 远程部署

NixOS Anywhere 允许你通过 SSH 将运行中的 Linux 系统（无论是否为 NixOS）替换为 NixOS。

#### 场景 A：服务器全新安装（推荐，全量格式化）

适用于新服务器或可以清空数据的机器。此方案最彻底、最自动化。

1. **准备 disko 配置**：在 flake 中定义磁盘分区，使用 `disko` 工具自动格式化。
2. **执行部署**：
   ```bash
   nix run github:nix-community/nixos-anywhere -- --flake .#your-host root@<IP>
   ```

#### 场景 B：现有系统迁移（保留数据分区）

适用于已有数据（如 `/home`, `/var`）且**有独立分区**的服务器。

⚠️ **风险警告**：默认情况下 NixOS Anywhere 会清空磁盘。要保留数据，必须在 `disko` 配置中**排除**数据分区，或仅对系统分区进行操作。

1. **配置策略**：
   * 在 `disko` 中**仅定义系统分区**（如 `/` 和 `/boot`）。
   * 在 `configuration.nix` 中通过 `fileSystems` 挂载现有的数据分区（不要通过 disko 格式化它们）。
   * **务必确认** `disko` 配置中没有包含数据分区的 `format` 操作。
2. **执行部署**：同场景 A。

---

### 2.5 从第三方 Linux 系统安装

适用于在没有 NixOS 官方安装介质的情况下，直接从其他 Linux 发行版（Ubuntu、Arch、Debian 等）安装 NixOS。

> 此流程仅在宿主机中提供安装所需的工具，**不会**修改当前宿主机的系统配置。实际的 NixOS 系统将被安装到你指定的目标硬盘（通常挂载在 `/mnt`）。

#### 步骤 1：安装 Nix 包管理器

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

#### 步骤 2：进入 NixOS 安装环境

```bash
nix --experimental-features "nix-command flakes" shell nixpkgs#nixos-install-tools
```

> 执行该命令后，终端提示符可能发生变化，表示已进入包含 `nixos-install` 等命令的 Shell 环境。如果提示找不到 `nixpkgs`，请使用完整路径：
> ```bash
> nix --experimental-features "nix-command flakes" shell github:NixOS/nixpkgs/nixos-unstable#nixos-install-tools
> ```

#### 步骤 3：分区与安装

进入安装环境后，后续操作与**通用安装流程**完全一致（克隆配置 → 分区 → 生成硬件配置 → 同步配置 → 安装 → 重启）。

安装完成后，退出当前 Shell，卸载目标分区并重启：
```bash
exit  # 退出 nix shell
sudo umount -R /mnt
sudo reboot
```

---

### 2.6 从 Arch Linux 原地迁移

如果你目前使用的是 Arch Linux，希望保留数据和桌面环境迁移到 NixOS，请参阅 **[upgrade-guide.md](./upgrade-guide.md)** 中的 **Arch Linux 原地升级指南**。

核心思路：在 Arch 中安装 Nix → 构建 NixOS 系统 → 设置 `/etc/NIXOS_LUSTRATE` 白名单 → 重启后自动保留 `/home` 等数据目录。

---

## 三、通用注意事项

### 3.1 密码设置风险 (`--no-root-passwd`)
* 使用 `nixos-install` 或 `nixos-anywhere` 时，如果添加了 `--no-root-passwd` 参数，Root 密码将为空。
* 如果你没有配置 SSH 公钥登录，重启后将**无法登录系统**。请务必确保配置中包含你的 SSH 公钥，或者在配置中设置了初始密码。

### 3.2 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 | 说明 |
|------|--------|------|
| `modules/common/users.nix` | `ssh-ed25519 AAAA...` | 替换为你的 SSH 公钥 |
| `modules/home/git.nix` | `you@example.com` | 替换为你的 Git 邮箱 |
| `hosts/*/hardware-configuration.nix` | UUID 占位符 | 替换为实际磁盘 UUID |

### 3.3 硬件配置与分区

| 文件 | 用途 | 适用场景 |
|------|------|----------|
| `disk.nix` | 声明式磁盘分区（执行时会格式化） | 服务器 / 虚拟机 / 全新安装 |
| `hardware-configuration.nix` | 记录当前分区 UUID、挂载点、内核模块 | 所有主机 |

- `hardware-configuration.nix` 由 `nixos-generate-config` 自动生成，**不应手动编辑**。
- 工作站通常已有分区，直接使用 `hardware-configuration.nix`，**不要**导入 `disk.nix`。
- 安装新机器或更换硬件后，重新生成并覆盖对应文件。

### 3.4 用户配置写法
* 推荐使用 `users.users.<name> = { ... };`。
* 在某些覆盖配置（Overlays）或 Home-Manager 集成场景下，可能会看到 `users.extraUsers.<name>` 的写法，两者在逻辑上等效，但 `extraUsers` 常用于模块化合并。

### 3.5 独立 Home 分区

如果你原本就有独立的 `/home` 分区：
1. 在 `hardware-configuration.nix` 中确保 `fileSystems."/home"` 配置正确
2. **不要**在 `disk.nix` 中定义 home 分区的格式化操作
3. 安装时直接挂载即可，数据会自动保留

### 3.6 显卡驱动

NVIDIA 显卡用户务必在配置中启用专有驱动，否则可能无法进入图形界面：

```nix
# 在 modules/gui/desktop.nix 或 hardware-configuration.nix 中
hardware.opengl.enable = true;
services.xserver.videoDrivers = [ "nvidia" ];
```

---

## 四、常见问题 (FAQ)

### Q: 安装时报错 `flake.cc:37: Assertion ... failed`？
这是 Nix flake 的 hash 断言错误，通常由 `flake.lock` 中的 narHash 与实际内容不匹配引起。常见于 Git 树有未提交更改时。

**解决方案：**
```bash
# 方案 1：确保所有更改已提交
git add -A && git commit -m "fix: ..."
nixos-install --flake ~/nixos-config#workstation --root /mnt

# 方案 2：临时跳过 lock file 写入（dirty tree 时的权宜之计）
nixos-install --flake ~/nixos-config#workstation --root /mnt --no-write-lock-file
```

### Q: 使用 `--option substitute false` 时报错 `path ... is not valid`？
说明本地 `/nix/store` 中没有包含目标配置所需的某个包。

**解决方案：**
1. 改用本地优先模式，让缺失的包走网络下载：
   ```bash
   sudo nixos-install --flake ~/nixos-config#workstation --root /mnt \
     --option substituters "file:///nix/store https://cache.nixos.org"
   ```
2. 或在构建 ISO 前，将缺失的包添加到 `modules/iso/cache.nix` 中，重新构建 ISO。

### Q: 如何验证安装是否在使用本地缓存？
观察安装输出：
- 看到 `copying path '/nix/store/...'` → 从本地复制
- 看到 `downloading from 'https://cache.nixos.org'` → 正在网络下载
- 使用 `--option substitute false` 时，若全程无 downloading 提示，即为纯离线安装。

### Q: 安装后无法从目标硬盘启动？
- 检查 BIOS/UEFI 启动顺序，确保目标硬盘在首位
- 确认 ESP 分区已正确挂载到 `/boot`
- 使用安装介质启动后，重新运行 `nixos-install`（它会修复 bootloader）

### Q: disko 报错 "device is busy"？
- 确认目标硬盘没有被挂载：`umount /dev/nvme0n1*`
- 如果有 swap 或 LVM，先停用：`swapoff -a`、`vgchange -an`

### Q: `nix flake update` 或 `nixos-rebuild` 报 public key 错误？
当在 portable 系统内部执行 `nix flake update` 时，如果出现 `public key is not valid` 错误，这是因为：

- **`nix flake update` 使用当前运行系统的 nix 配置**（`/etc/nix/nix.conf`），而非 flake 里声明的配置
- 如果 `/etc/nix/nix.conf` 中的公钥有误（如 `cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkb16ZPMQFGspcDShjY=` 缺少字母 `J`），就会报签名验证失败
- 这是"鸡生蛋"问题：错误的配置导致无法 update，而 update 后才能重建正确的配置

**解决方案（任选其一）：**

1. **命令行覆盖公钥（推荐）**：
   ```bash
   nix flake update --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY='
   ```

2. **临时禁用签名校验（更简单）**：
   ```bash
   nix flake update --option require-sigs false
   ```

修复后，执行 `sudo nixos-rebuild switch` 重建系统，将正确的配置永久写入 `/etc/nix/nix.conf`。

> **注意**：宿主机（如 Arch Linux）的 nix 配置通常没问题，所以在本机执行 `nix flake update` 不会报错。问题只出现在 portable 系统内部。

### 2.5 更新已安装的系统（外部挂载场景）

当你已经在目标磁盘安装好了系统，但在 Live CD 或另一台机器（如 portable）上挂载该磁盘到 `/mnt` 进行配置更新时，请使用 `nixos-install` 而不是 `nixos-rebuild`。

> **注意**：新版 `nixos-rebuild` 已移除 `--root` 参数，它仅用于更新当前正在运行的系统。

#### 命令

```bash
# 正确：使用 nixos-install 更新外部磁盘
sudo nixos-install --root /mnt --no-root-password --flake .#server
```

- `--no-root-password`：**重要**。避免重置已有系统的 root 密码和用户账户状态。
- 如果不加此参数，脚本会交互式要求你重新设置 root 密码，可能会覆盖现有配置。

---

## 📚 官方文档与参考资料

- [NixOS 官方手册](https://nixos.org/manual/nixos/stable/)
- [Flakes 文档](https://nixos.wiki/wiki/Flakes)
- [disko 文档](https://github.com/nix-community/disko)
- [Home Manager 配置选项](https://nix-community.github.io/home-manager/options.xhtml)
- [NIXOS_LUSTRATE 说明](https://nixos.org/manual/nixos/stable/#sec-upgrading-notes)
- [nixos-install 说明](https://nixos.org/manual/nixos/stable/#sec-installation)
- [COSMIC DE 文档](https://github.com/pop-os/cosmic-epoch)
- [NixOS 包搜索](https://search.nixos.org/packages)