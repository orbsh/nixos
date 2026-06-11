# NixOS Configuration

> 基于 NixOS unstable 的模块化 Flakes 配置，采用 **域（Domain）→ 预设（Preset）→ 桌面预设（Desktop Preset）** 三层架构。

---

## 🏗 架构概览

```
flake.nix              ← Flake 入口，自动发现 hosts/ 下的域
  └── hosts/<domain>/  ← 域定义（workstations/k8s-dev/portable/qemu/server...）
        └── presets/<preset>.nix  ← 系统预设（workstation-base/server/portable/qemu）
              └── desktop/<preset>.nix  ← 桌面预设（mini/base/full）
                    └── desktop/units/*.nix  ← 桌面组件单元
```

### 设计原则

**引入即启用**：模块被 `imports` 后即自动生效，不依赖额外的 `enable` 开关。配置加载路径 = 最终效果，避免隐式状态。

**模块系统类型安全**：
- 引入模块 + 设置选项 → ✓ 正常
- 引入模块 + 不设置选项 → ✓ 正常（使用默认值）
- 不引入模块 + 设置选项 → ✗ 报错（选项不存在）
- 不引入模块 + 不设置选项 → ✓ 正常

> 其他模块可通过 `config.services.<name>.enable or false` 检测某模块是否被引入（NixOS 内置选项始终存在，未引入时为默认值）。

### 构建流程

```
flake.nix 扫描 hosts/ 目录
  ├── 域定义包含 nodes 属性 → K8s 集群模式 → k8s-libs.nix 展开节点
  └── 域定义不包含 nodes → 单机模式 → 直接构建
        └── nixos-builder.nix 统一构建所有节点
              ├── baseModules（所有节点共享：disko + home-manager 集成）
              ├── networkModule（有 ip 时配置 eth0）
              ├── hostnameModule（有 hostname 时设置）
              ├── nodeConfigModule（节点自定义配置）
              └── node.imports（节点导入的预设/模块）
```

---



## 🖥 桌面预设层级

三个独立预设，互不依赖：

| 预设 | 用途 | 包含组件 | Hyprland |
|------|------|---------|----------|
| `desktop/mini.nix` | QEMU 虚拟机 | apps-core, hyprland, greetd, 输入法, 字体, 无障碍, eww | ✅ |
| `desktop/base.nix` | 便携系统 | mini + cosmic + apps-core + hyprland + eww | ✅ |
| `desktop/full.nix` | 完整工作站 | base + apps-extra, apps-im, laptop, zed, rime | ✅ |

**设计原则**：每个预设自包含，不互相 import，改一个不影响其他。

### 桌面单元（units）

| 单元 | 用途 |
|------|------|
| `cosmic.nix` | COSMIC 桌面环境 |
| `greetd.nix` | greetd 登录管理器 |
| `input-method.nix` | fcitx5 中文输入法 |
| `fonts.nix` | 字体配置 |
| `accessibility.nix` | 无障碍支持 |
| `apps-core.nix` | 核心应用（终端、编辑器、浏览器基础、媒体工具） |
| `apps-extra.nix` | 额外应用（办公、阅读、创作工具） |
| `apps-im.nix` | 即时通讯应用 |
| `hyprland.nix` | Hyprland 合成器 + 辅助工具链（waybar, wofi, grim 等） |
| `eww.nix` | Eww Wayland 状态栏（替代 waybar） |
| `laptop.nix` | 笔记本电源管理 |
| `zed.nix` | Zed 编辑器 |
| `rime.nix` | Rime 输入法（NixOS 级模块） |
| `vivaldi.nix` | Vivaldi 浏览器 + Wayland 缩放修复 |
| `home-desktop.nix` | 桌面 HM 聚合（home-terminals + home-xdg） |
| `home-terminals.nix` | 终端配置（ghostty + alacritty + zellij） |
| `home-xdg.nix` | XDG 配置（mimeApps + userDirs + BROWSER） |

---

## 📋 Host 加载路径
### 1. Workstations（orbit / team-alice / team-bob）

```
hosts/workstations/default.nix
  └── presets/workstation-base.nix
        ├── system/core.nix              (核心系统: sys, base, nix, users, network, extra, container, media)
        ├── system/home.nix              (Home Manager 聚合: home-base, home-shell, home-editors, home-git)
        ├── system/units/hardware-generic.nix  (通用硬件配置)
        ├── services/virt.nix              (libvirtd/virt-manager)
        ├── desktop/full.nix             (完整桌面预设)
        │     ├── units/cosmic.nix
        │     ├── units/greetd.nix
        │     ├── units/input-method.nix
        │     ├── units/fonts.nix
        │     ├── units/accessibility.nix
        │     ├── units/apps-core.nix
        │     │     ├── units/vivaldi.nix ❌ (已移至 apps-extra)
        │     │     ├── units/zed.nix
        │     │     └── systemPackages: ghostty, alacritty, mpv, ffmpeg, firefox, chromium, flameshot 等
        │     ├── units/apps-extra.nix
        │     │     ├── units/vivaldi.nix ✅
        │     │     └── systemPackages: smplayer, krita, blender, calibre, zathura 等
        │     ├── units/apps-im.nix
        │     ├── units/hyprland.nix     (waybar, wofi, grim, slurp, hyprpaper, cliphist 等)
        │     ├── units/laptop.nix
        │     ├── units/zed.nix
        │     └── hyprland.enable = true
        ├── desktop/home.nix             (桌面 Home Manager: home-terminals, home-xdg)
        ├── dev/fullstack.nix            (Python, Rust, JS, Haskell, K8s, WASM 开发工具)
        ├── services/hermes-system.nix (Hermes Agent)
        ├── services/harmonia.nix      (本地二进制缓存 :5100)
        ├── services/ladder.nix        (Podman 代理链)
        └── services/podman-apps.nix   (Podman 应用全家桶)

```

**nushell 配置**：`developMode = true` → symlink 到 `~/Configuration/nushell`（详见 [ADR-003](docs/adr/003-nushell-version-develop-mode.md)）

---

### 2. Portable（便携系统盘）

```
hosts/portable/default.nix
  ├── presets/portable.nix
  │     ├── system/core.nix              (同上)
  │     ├── system/home.nix              (Home Manager 聚合)
  │     ├── system/units/hardware-generic.nix
  │     ├── desktop/base.nix             (基础桌面预设)
  │     │     ├── units/cosmic.nix
  │     │     ├── units/greetd.nix
  │     │     ├── units/input-method.nix
  │     │     ├── units/fonts.nix
  │     │     ├── units/accessibility.nix
  │     │     ├── units/apps-core.nix
  │     │     ├── units/hyprland.nix
  │     │     └── hyprland.enable = true
  │     ├── desktop/home.nix             (桌面 Home Manager)
  │     └── podman/ladder.nix            (Podman 代理)
  └── flake-srv/harmonia.nix             (本地二进制缓存 :5100，节点级单独引入)
```

**与 workstation 的区别**：
- 无 `dev/fullstack.nix`（无开发工具链）
- 无 `podman/full.nix`（仅 ladder 代理）
- 使用 `base.nix` 而非 `full.nix`（无 apps-extra/apps-im/laptop）
- nushell `developMode = false` → 通过 flake input 部署（详见 [ADR-003](docs/adr/003-nushell-version-develop-mode.md)）
- 启用 `udisks2`（可移动设备自动挂载）
- 启用 `getty.autologinUser`（自动登录）

---

### 3. QEMU（虚拟机）

```
hosts/qemu/default.nix
  └── presets/qemu.nix
        ├── disko.nixosModules.disko
        ├── system/core.nix              (同上)
        ├── system/home.nix              (Home Manager 聚合)
        ├── desktop/mini.nix             (最小桌面预设)
        │     ├── units/cosmic.nix
        │     ├── units/greetd.nix
        │     ├── units/input-method.nix
        │     ├── units/fonts.nix
        │     └── units/accessibility.nix
        │     (无 hyprland，无 apps)
        ├── desktop/home.nix             (桌面 Home Manager)
        └── dev/server.nix               (开发工具)
```

**特殊配置**：
- `services.spice-vdagentd.enable = true`（SPICE 剪贴板/分辨率自适应）
- `boot.kernelPackages = pkgs.linuxPackages`（稳定内核，非 latest）
- 无开发工具，无 Hyprland

---

### 4. Server（独立服务器）

```
hosts/server/default.nix
  └── presets/server.nix
        ├── system/core.nix              (同上)
        ├── system/home.nix              (Home Manager 聚合: home-base, home-shell, home-editors, home-git)
        ├── system/units/hardware-generic.nix
        ├── system/virt.nix
        ├── dev/server.nix               (服务器开发工具)
        └── flake-srv/harmonia.nix       (本地二进制缓存 :5100)
```

**特点**：无桌面环境，无图形界面，headless 模式。

---

### 5. K8s 集群（k8s-dev / k8s-small-cluster / k8s-large-cluster）

K8s 节点通过 `k8s-libs.nix` 的 `expandCluster` 函数构建，自动注入：

```
k8s-libs.nix → expandCluster → buildNode
  ├── presets/server.nix           ← 所有 K8s 节点自动继承服务器预设
  ├── k8sRoleModules             ← control / worker / combo 角色模块
  │     ├── control: k8s-control.nix
  │     ├── worker: k8s-worker.nix
  │     └── combo: k8s-control.nix + k8s-worker.nix + 移除 taint
  ├── clusterModules             ← 域级共享模块（如 registries-gen）
  ├── runtimeModules             ← crio / containerd
  ├── k8s 配置模块               (kubernetes, apiserver SANs, cert sync 等)
  └── node.imports               ← 节点特有导入（硬件、wireguard、coredns 等）
```

**k8s-dev/dxserver 示例**：
```
hosts/k8s-dev/default.nix
  └── nodes.dxserver
        ├── presets/server.nix           (自动注入)
        │     ├── system/core.nix
        │     ├── system/home.nix        (Home Manager 聚合)
        │     ├── system/units/hardware-generic.nix
        │     ├── system/virt.nix
        │     └── dev/server.nix
        ├── k8s-role: combo            (control + worker 合一)
        ├── runtime: containerd
        ├── server/hardware/disk.nix
        ├── server/hardware/hardware-configuration.nix
        ├── server/hardware/wireguard.nix
        └── modules/k8s/coredns.nix    (内网 DNS)
```

---

### 6. ISO（nixos-anywhere 专用 Live 镜像）

```n
modules/iso/default.nix          ← ISO 入口（不依赖 installation-cd-minimal）
  ├── iso-image.nix               ← NixOS 最小 ISO 构建器
  ├── system/units/nix.nix        ← Nix 生态工具（nh, nixos-anywhere, cachix 等）
  └── units/                      ← 用户配置（内联 HM 模块）
        ├── home-editors.nix       ← Helix 主题 + LSP + 快捷键
        ├── home-git.nix          ← Git 配置（用户名/邮箱）
        └── home-base.nix         ← 通用用户配置
```

**设计原则**：
- 不基于 `installation-cd-minimal.nix`，直接用 `iso-image.nix` 从零构建
- 体积 **~781MB**（官方最小安装盘 ~1.5GB）
- 无 GUI，纯 headless
- SSH 默认开启 + 内置公钥 + root 可登录
- nushell 配置通过 store copy 注入（避免 symlink 导致 xorriso 报错）

**构建命令**：
```bash
nix build .#iso.config.system.build.isoImage
```

**产物**：`result/iso/nixos-*.iso`

---

## 📁 目录结构

```
nixos/
├── flake.nix                     # Flake 入口 + 自动发现逻辑
├── libs/
│   ├── nixos-builder.nix         # 统一节点构建器
│   ├── registries-gen.nix        # 容器 registry 配置生成器
│   └── local-pkg.nix             # 本地包引用工具
├── hosts/                        # 域定义
│   ├── workstations/             # 工作站域（orbit/alice/bob）
│   ├── portable/                 # 便携系统域
│   ├── qemu/                     # QEMU 虚拟机域
│   ├── server/                   # 独立服务器域
│   ├── k8s-dev/                  # K8s 开发集群
│   ├── k8s-small-cluster/        # K8s 小集群
│   └── k8s-large-cluster/        # K8s 大集群
└── modules/
    ├── system/                   # 系统级模块
    │   ├── core.nix              # 核心预设（sys, base, nix, users, network, extra, container, media）
    │   ├── home.nix              # Home Manager 聚合（home-base, home-shell, home-editors, home-git）
    │   ├── assets/               # 共享资源（zellij 配置等）
    │   └── units/                # 系统单元 + HM 单元（home-*.nix）
    ├── desktop/                  # 桌面预设
    │   ├── mini.nix              # 最小桌面（QEMU）
    │   ├── base.nix              # 基础桌面（portable）
    │   ├── full.nix              # 完整桌面（workstation）
    │   ├── home.nix              # 桌面 Home Manager（home-terminals, home-xdg）
    │   └── units/                # 桌面组件单元 + HM 单元（home-terminals, home-xdg）
    ├── presets/                    # 系统预设
    │   ├── workstation-base.nix  # 工作站基座
    │   ├── server.nix            # 服务器基座
    │   ├── portable.nix          # 便携系统基座
    │   └── qemu.nix              # QEMU 虚拟机基座
    ├── overlay/                  # 包覆盖（仅 workstations 域）
    │   └── nushell.nix           # nushell 0.113.0 官方 musl 二进制
    ├── dev/                      # 开发工具模块
    │   └── units/
    │       └── surrealdb-server.nix  # SurrealDB 服务（模块级 overlay 固定版本）
    ├── podman/                   # Podman 相关模块
    ├── k8s/                      # Kubernetes 模块
    ├── flake-srv/                # Flake 服务器模块
    └── iso/                      # nixos-anywhere 专用 Live ISO（~781MB）
          ├── default.nix          # ISO 入口（iso-image.nix + GRUB 引导）
          └── (cache.nix 已删除)
```

---

## 🔀 Overlay 策略

本项目采用**选项驱动 overlay 架构**：模块内聚在 `modules/*/units/` 中，host 文件只设选项值。详见 [ADR-002: Overlay by Domain](docs/adr/002-overlay-by-domain.md)。

### 核心原则

**模块定义逻辑（`modules/`），host 文件只设选项值（`hosts/`）。**

所有 overlay 模块统一放在 `modules/*/units/` 中，由 `<presets>.nix` 统一引入。host 文件只负责设置选项值，不碰逻辑。

- **未设置选项** → overlay 关闭，用 nixpkgs 默认包
- **设置了选项** → overlay 开启，替换为自定义包

### 示例

```nix
# modules/system/units/nushell.nix — 定义选项 + overlay 逻辑
# hosts/workstations/nushell.nix  — 只设选项值
# hosts/workstations/vivaldi.nix  — 只设选项值（同模式）
# hosts/workstations/wanxiang.nix — 只设选项值（同模式）
```

### 选择指南

| 需求 | 方案 |
|------|------|
| 全局包替换 | `modules/*/units/` + 选项驱动 |
| 桌面应用定制 | `modules/*/units/` + 选项驱动 |
| 仅改一个服务的包 | 服务级覆盖 |

---

## 🔧 常用命令

```bash
# 构建 nixos-anywhere 专用 ISO
nix build .#iso.config.system.build.isoImage

# 重建工作站
sudo nixos-rebuild switch --flake .#workstations_orbit

# 重建便携系统（在宿主机上）
use x.nu portable
portable switch

# 重建 K8s 节点
sudo nixos-rebuild switch --flake .#k8s-dev_dxserver

# 重建 QEMU
sudo nixos-rebuild switch --flake .#qemu
```

> **禁止 `--impure`**：本配置通过 `nix store add-file` 管理大体积外部文件（Vivaldi deb 包、Rime 数据等），保持 Nix purity。详见 [ADR-001: 大体积外部文件的源管理策略](docs/adr/001-large-external-files.md)。

---

## ⚠️ 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 |
|------|--------|
| `flake.nix` | `user = "master"` → 你的用户名 |
| `flake.nix` | `email = "nash@iffy.me"` → 你的邮箱 |
| `flake.nix` | `sshPublicKey` → 你的 SSH 公钥（全局唯一） |

---

## 📎 附录：网络与 DNS 配置

### 网络配置

| 场景 | 配置方式 | 模块位置 |
|------|----------|----------|
| **Workstation/Portable** | NetworkManager + DHCP | `system/units/sys.nix` |
| **K8s 静态 IP** | `nixos-builder.nix` networkModule | 通过 `nodeAttrs.ip` 配置 |
| **K8s DHCP** | NetworkManager | `nodeAttrs.useDHCP = true` |

**关键点**：
- 静态 IP 节点通过 `nixos-builder.nix` 的 `networkModule` 配置 eth0
- `useDHCP = false` 时禁用 DHCP，使用静态 IP
- NetworkManager 默认启用（`system/units/sys.nix`）

### DNS 架构

采用分层解析 + 全局公共 DNS 策略，支持有/无宿主机 CoreDNS 两种场景自动适配。详见 [ADR-012: K8s DNS 架构](docs/adr/012-k8s-dns-architecture.md)。

#### DNS 链路（无宿主机 CoreDNS）

```
Pod 查询外部域名
  → kube-dns ClusterIP (10.0.0.254)
  → 集群内 CoreDNS pod
  → Corefile: forward . 223.5.5.5 119.29.29.29 1.1.1.1
  → 公共 DNS
```

#### 配置位置

| 配置项 | 文件 | 说明 |
|--------|------|------|
| 公共 DNS 列表 | `flake.nix` | `commonArgs.publicDnsServers` |
| 宿主机 CoreDNS | `modules/services/coredns.nix` | 引入即启用 |
| kubelet resolv.conf | `modules/k8s/k8s-common.nix` | 条件判断 |
| CoreDNS Corefile | `modules/k8s/assets/patch-coredns.sh` | 运行时 patch |
