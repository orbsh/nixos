# NixOS Configuration

> 基于 NixOS unstable 的模块化 Flakes 配置，采用 **域（Domain）→ 角色（Role）→ 桌面预设（Desktop Preset）** 三层架构。

---

## 🏗 架构概览

```
flake.nix              ← Flake 入口，自动发现 hosts/ 下的域
  └── hosts/<domain>/  ← 域定义（workstations/k8s-dev/portable/qemu/server...）
        └── roles/<role>.nix  ← 角色预设（workstation-base/server/portable/qemu）
              └── desktop/<preset>.nix  ← 桌面预设（mini/base/full）
                    └── desktop/units/*.nix  ← 桌面组件单元
```

### 构建流程

```
flake.nix 扫描 hosts/ 目录
  ├── 域定义包含 nodes 属性 → K8s 集群模式 → k8s-libs.nix 展开节点
  └── 域定义不包含 nodes → 单机模式 → 直接构建
        └── nixos-builder.nix 统一构建所有节点
              ├── baseModules（所有节点共享：core.nix + disko + home-manager）
              ├── networkModule（有 ip 时配置 eth0）
              ├── hostnameModule（有 hostname 时设置）
              ├── nodeConfigModule（节点自定义配置）
              └── node.imports（节点导入的角色/模块）
```

---

## 🖥 桌面预设层级

三个独立预设，互不依赖：

| 预设 | 用途 | 包含组件 | Hyprland |
|------|------|---------|----------|
| `desktop/mini.nix` | QEMU 虚拟机 | cosmic, greetd, 输入法, 字体, 无障碍 | ❌ |
| `desktop/base.nix` | 便携系统 | mini 全部 + apps-core + hyprland | ✅ |
| `desktop/full.nix` | 完整工作站 | base 全部 + apps-extra, apps-im, laptop, zed | ✅ |

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
| `laptop.nix` | 笔记本电源管理 |
| `zed.nix` | Zed 编辑器 |
| `vivaldi.nix` | Vivaldi 浏览器 + Wayland 缩放修复 |

---

## 📋 Host 加载路径详解

### 1. Workstations（orbit / team-alice / team-bob）

```
hosts/workstations/default.nix
  └── roles/workstation-base.nix
        ├── system/core.nix
        │     ├── units/sys.nix          (bootloader, kernel, NetworkManager, pipewire, keymap)
        │     ├── units/base.nix         (系统包: git, curl, nushell, zellij 等)
        │     ├── units/nix.nix          (nix 配置, substituters)
        │     ├── units/users.nix        (用户配置)
        │     ├── units/network.nix      (网络配置)
        │     ├── units/extra.nix        (额外系统工具)
        │     ├── units/container.nix    (podman)
        │     └── units/media.nix        (媒体编解码器)
        ├── system/units/hardware-generic.nix  (通用硬件配置)
        ├── system/units/vm.nix          (libvirtd/virt-manager)
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
        ├── dev/fullstack.nix            (Python, Rust, JS, Haskell, K8s, WASM 开发工具)
        ├── podman/full.nix              (Podman 全家桶)
        └── flake-srv/hermes-system.nix  (Hermes Agent)
        └── home/desktop.nix             (Home Manager)
              ├── units/common.nix
              ├── units/shell.nix        (nushell 配置, developMode = true → 本地 symlink)
              ├── units/editors.nix      (helix, neovim)
              ├── units/terminals.nix
              ├── units/git.nix
              ├── units/xdg.nix
              ├── units/rime.nix
              ├── units/eww.nix
              └── programs.home-manager.enable = true
```

**nushell 配置**：`developMode = true` → symlink 到 `~/Configuration/nushell`

---

### 2. Portable（便携系统盘）

```
hosts/portable/default.nix
  └── roles/portable.nix
        ├── system/core.nix              (同上)
        ├── system/units/hardware-generic.nix
        ├── desktop/base.nix             (基础桌面预设)
        │     ├── units/cosmic.nix
        │     ├── units/greetd.nix
        │     ├── units/input-method.nix
        │     ├── units/fonts.nix
        │     ├── units/accessibility.nix
        │     ├── units/apps-core.nix
        │     ├── units/hyprland.nix
        │     └── hyprland.enable = true
        ├── podman/ladder.nix            (Podman 代理)
        └── home/desktop.nix             (Home Manager，同 workstation)
              ├── units/shell.nix        (nushell 配置, developMode = false → flake input symlink)
              └── ...
```

**与 workstation 的区别**：
- 无 `dev/fullstack.nix`（无开发工具链）
- 无 `podman/full.nix`（仅 ladder 代理）
- 使用 `base.nix` 而非 `full.nix`（无 apps-extra/apps-im/laptop）
- nushell `developMode = false` → 通过 flake input 部署
- 启用 `udisks2`（可移动设备自动挂载）
- 启用 `getty.autologinUser`（自动登录）

---

### 3. QEMU（虚拟机）

```
hosts/qemu/default.nix
  └── roles/qemu.nix
        ├── disko.nixosModules.disko
        ├── system/core.nix              (同上)
        ├── desktop/mini.nix             (最小桌面预设)
        │     ├── units/cosmic.nix
        │     ├── units/greetd.nix
        │     ├── units/input-method.nix
        │     ├── units/fonts.nix
        │     └── units/accessibility.nix
        │     (无 hyprland，无 apps)
        └── home/desktop.nix             (Home Manager)
              └── ...
```

**特殊配置**：
- `services.spice-vdagentd.enable = true`（SPICE 剪贴板/分辨率自适应）
- `boot.kernelPackages = pkgs.linuxPackages`（稳定内核，非 latest）
- 无开发工具，无 Hyprland

---

### 4. Server（独立服务器）

```
hosts/server/default.nix
  └── roles/server.nix
        ├── system/core.nix              (同上)
        ├── system/units/hardware-generic.nix
        ├── system/units/vm.nix
        ├── dev/server.nix               (服务器开发工具)
        └── home/headless.nix            (Home Manager)
              ├── units/common.nix
              ├── units/shell.nix        (nushell, developMode = false)
              ├── units/editors.nix      (helix)
              ├── units/git.nix
              └── programs.home-manager.enable = true
```

**特点**：无桌面环境，无图形界面，headless 模式。

---

### 5. K8s 集群（k8s-dev / k8s-small-cluster / k8s-large-cluster）

K8s 节点通过 `k8s-libs.nix` 的 `expandCluster` 函数构建，自动注入：

```
k8s-libs.nix → expandCluster → buildNode
  ├── roles/server.nix           ← 所有 K8s 节点自动继承服务器角色
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
        ├── roles/server.nix           (自动注入)
        │     ├── system/core.nix
        │     ├── system/units/hardware-generic.nix
        │     ├── system/units/vm.nix
        │     ├── dev/server.nix
        │     └── home/headless.nix
        ├── k8s-role: combo            (control + worker 合一)
        ├── runtime: containerd
        ├── server/hardware/disk.nix
        ├── server/hardware/hardware-configuration.nix
        ├── server/hardware/wireguard.nix
        └── modules/k8s/coredns.nix    (内网 DNS)
```

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
    │   ├── core.nix              # 核心预设（所有节点默认加载）
    │   └── units/                # 系统单元
    ├── desktop/                  # 桌面预设
    │   ├── mini.nix              # 最小桌面（QEMU）
    │   ├── base.nix              # 基础桌面（portable）
    │   ├── full.nix              # 完整桌面（workstation）
    │   └── units/                # 桌面组件单元
    ├── roles/                    # 角色预设
    │   ├── workstation-base.nix  # 工作站基座
    │   ├── server.nix            # 服务器基座
    │   ├── portable.nix          # 便携系统基座
    │   └── qemu.nix              # QEMU 虚拟机基座
    ├── home/                     # Home Manager 配置
    │   ├── desktop.nix           # 桌面用户环境
    │   ├── headless.nix          # 无头用户环境
    │   └── units/                # Home Manager 单元
    ├── dev/                      # 开发工具模块
    ├── podman/                   # Podman 相关模块
    ├── k8s/                      # Kubernetes 模块
    ├── flake-srv/                # Flake 服务器模块
    └── iso/                      # Live ISO 配置
```

---

## 🔧 常用命令

```bash
# 重建工作站
sudo nixos-rebuild switch --flake .#workstations_orbit --impure

# 重建便携系统（在宿主机上）
use x.nu portable
portable switch

# 重建 K8s 节点
sudo nixos-rebuild switch --flake .#k8s-dev_dxserver --impure

# 重建 QEMU
sudo nixos-rebuild switch --flake .#qemu --impure
```

> **`--impure` 说明**：本配置使用本地路径引用（Vivaldi deb 包、Rime 数据等），需要 `--impure` 标志。

---

## ⚠️ 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 |
|------|--------|
| `flake.nix` | `user = "master"` → 你的用户名 |
| `flake.nix` | `email = "nash@iffy.me"` → 你的邮箱 |
