# NixOS 26 Flake Configuration

> 基于 NixOS unstable 的模块化 Flakes 配置，支持 **工作站 (workstation)**、**服务器 (server)** 与 **虚拟机 (vbox)** 三台主机。

---

## 📁 目录结构

```
nixos26/
├── flake.nix                     # Flake 入口，定义三台主机 + ISO 构建
├── hosts/
│   ├── workstation/              # COSMIC 桌面工作站
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   ├── server/                   # 无头服务器 (K8s/Nomad 二选一)
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── vbox/                     # VirtualBox 虚拟机
│       ├── default.nix
│       └── hardware-configuration.nix
└── modules/
    ├── common/                   # 通用模块（所有主机共享）
    │   ├── base.nix              # Nix 配置、locale、SSH、sysctl、核心 CLI 工具
    │   ├── extra.nix             # 额外工具：glow、fzf、duckdb、termshark
    │   ├── sys.nix               # systemd-boot、NetworkManager、pipewire、polkit、keymap
    │   ├── network.nix           # 防火墙 + WireGuard 接口
    │   ├── users.nix             # 用户 master、SSH 密钥、wheel 组
    │   └── container.nix         # 容器运行时：Podman (启用) + Containerd (默认禁用)
    ├── workstation/              # 工作站专用模块
    │   ├── desktop.nix           # COSMIC DE、fcitx5、字体
    │   ├── apps-core.nix         # 核心应用：终端/编辑器/浏览器/媒体
    │   ├── apps-im.nix           # 微信 (wechat-uos)
    │   ├── extra.nix              # 增强应用（WPS Office, Zathura, Surrealist 等）
    │   ├── dev.nix               # 开发工具：Rust/Haskell/Bun/Python/WASM
    │   └── nomad.nix             # Nomad Client（开发调试）
    ├── server/                   # 服务器专用模块
    │   ├── k8s.nix               # Kubernetes 集群（与 Nomad 二选一）
    │   ├── nomad.nix             # HashiCorp Nomad（与 K8s 二选一）
    └── home/                     # Home Manager 用户环境配置
        ├── desktop/              # 桌面 profile 入口
        │   └── default.nix       # 用户名、home 包列表（桌面版）
        ├── server/               # 服务器 profile 入口
        │   └── default.nix       # 用户名、home 包列表（服务器版）
        ├── shell.nix             # Nushell 启用 + 配置库链接
        ├── editors.nix           # Helix + Neovim + Zed 配置
        ├── terminals.nix         # Ghostty + Zellij 配置
        ├── git.nix               # Git + lazygit + delta 配置
        └── xdg.nix               # XDG 配置（注意：与 shell.nix 有重复，建议二选一）
```

---

## 📖 配置说明与简单教程

### 什么是 Flake？

Flake 是 Nix 的新一代包管理方式，通过 `flake.nix` 声明输入依赖（如 nixpkgs、home-manager、disko）和输出配置。相比传统 channels，Flake 提供**可复现的锁定**（`flake.lock`）。

### 核心概念

| 概念 | 说明 |
|------|------|
| `nixosConfigurations` | 在 `flake.nix` 中定义的机器配置（workstation / server / vbox） |
| `modules` | 可复用的 NixOS 配置片段，通过 `imports` 组合 |
| `home-manager` | 用 Nix 语法管理用户级配置（dotfiles、GUI 应用） |
| `disko` | 声明式磁盘分区工具，支持一键格式化安装 |
| `nixos-generators` | 用于构建自定义 Live ISO 镜像 |

### 配置层级

```
flake.nix (定义主机)
  └── hosts/workstation/default.nix (主机入口)
        ├── hosts/workstation/hardware-configuration.nix (硬件扫描，自动生成)
        ├── modules/common/*    (通用层)
        └── modules/workstation/* (工作站层)
              └── modules/home/* (用户层，通过 home-manager 注入)
```

---

## 🔧 系统安装流程

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

### 2. 分区与挂载

**使用 disko 自动分区（推荐）：**
```bash
sudo -i
# 确认磁盘设备名
lsblk

# 应用磁盘配置（以服务器为例）
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko ./hosts/server/default.nix
```

### 3. 生成硬件配置

```bash
nixos-generate-config --root /mnt
```

⚠️ **重要：** 该命令会生成 `hardware-configuration.nix`，包含内核模块和文件系统 UUID。
请将生成的内容覆盖到对应主机的硬件配置文件中：
- 工作站 → `hosts/workstation/hardware-configuration.nix`
- 服务器 → `hosts/server/hardware-configuration.nix`
- 虚拟机 → `hosts/vbox/hardware-configuration.nix`

### 4. 同步配置文件

```bash
# 将整个 nixos26 目录复制到 /mnt/etc/nixos
cp -r /path/to/this/repo/Configuration/nixos26/* /mnt/etc/nixos/
```

### 5. 安装系统

```bash
# 安装工作站
nixos-install --root /mnt --flake /mnt/etc/nixos#workstation

# 安装服务器
nixos-install --root /mnt --flake /mnt/etc/nixos#server

# 安装虚拟机
nixos-install --root /mnt --flake /mnt/etc/nixos#vbox

# 设置 root 密码
passwd

# 卸载并重启
umount -R /mnt
reboot
```

---

## 🚀 日常操作流程

### 更新系统

```bash
# 更新 flake 输入（拉取最新 nixpkgs）
nix flake update

# 重建并切换（不重启）
sudo nixos-rebuild switch --flake .#workstation

# 重建并重启（内核更新时必须）
sudo nixos-rebuild switch --flake .#workstation --upgrade
```

### 切换世代与回滚

```bash
# 查看已安装的世代
nix-env --list-generations --profile /nix/var/nix/profiles/system

# 运行时回滚到上一世代
sudo nix-env --rollback --profile /nix/var/nix/profiles/system
```

### 清理垃圾

```bash
# 删除未被当前世代引用的包
sudo nix-collect-garbage -d

# 删除旧世代（保留最近 5 个）
sudo nix-env --delete-generations old --profile /nix/var/nix/profiles/system

# 优化 Nix Store
sudo nix optimise-store
```

### 搜索包

```bash
# 命令行搜索
nix search nixpkgs#<keyword>

# 或在线搜索：https://search.nixos.org/packages
```

### Home Manager 更新

Home Manager 随 `nixos-rebuild` 自动更新。如需单独应用：
```bash
home-manager switch --flake .#master
```

---

## 💻 预装开发环境

以下工具已随系统安装，开箱即用，标准命令即可使用：

| 语言/运行时 | 包含组件 |
|-------------|----------|
| **Bun** | JS/TS 主运行时 |
| **Rust** | rustup, cargo, sccache, rust-analyzer |
| **Haskell** | GHC, cabal, stack, HLS |
| **Python** | uv + fastapi, uvicorn, pytest, pydantic, polars, ipython 等 |
| **WASM** | wasmtime |
| **C/C++** | gcc, cmake, gnumake, pkg-config |

> 注：各语言的具体用法（如 `cargo build`、`cabal init`、`uv add`）与 NixOS 无关，请参考官方文档。




---

## 📦 如何运行静态编译的二进制文件

NixOS 的动态链接器路径特殊，直接运行外部二进制文件可能失败。以下是解决方案：

### 方案 1：使用 `nix-ld`（推荐）

```nix
# 在模块中添加：
programs.nix-ld.enable = true;
programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc zlib openssl ];
```

### 方案 2：直接运行真正的静态二进制文件

完全静态编译（musl）的二进制文件可直接运行：
```bash
chmod +x ./static-binary
./static-binary

# 验证是否为静态：
file ./binary  # 应显示 "statically linked"
ldd ./binary   # 应显示 "not a dynamic executable"
```

### 方案 3：使用 `patchelf`

```bash
nix-shell -p patchelf
patchelf --set-interpreter "$(cat /nix/var/nix/profiles/system/sw/lib/ld-linux-x86-64.so.2)" ./binary
```

---

## ⚠️ 注意事项

### 硬件配置

`hardware-configuration.nix` 由 `nixos-generate-config` 自动生成，**不应手动编辑**。
安装新机器或更换硬件后，重新生成并覆盖对应文件。

### 占位符替换

使用前请修改以下占位符：

| 文件 | 占位符 | 说明 |
|------|--------|------|
| `modules/common/users.nix` | `ssh-ed25519 AAAA...` | 替换为你的 SSH 公钥 |
| `modules/home/git.nix` | `you@example.com` | 替换为你的 Git 邮箱 |
| `hosts/*/hardware-configuration.nix` | UUID 占位符 | 替换为实际磁盘 UUID |
| `hosts/server/disk.nix` | `/dev/sda` | 确认实际磁盘设备名 |
| `hosts/vbox/disk.nix` | `/dev/sda` | 确认实际磁盘设备名 |


---

## 🔗 参考资料

- [NixOS 官方手册](https://nixos.org/manual/nixos/stable/)
- [Flakes 文档](https://nixos.wiki/wiki/Flakes)
- [Home Manager 配置选项](https://nix-community.github.io/home-manager/options.xhtml)
- [disko 文档](https://github.com/nix-community/disko)
- [COSMIC DE 文档](https://github.com/pop-os/cosmic-epoch)
- [NixOS 包搜索](https://search.nixos.org/packages)
