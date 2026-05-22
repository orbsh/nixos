# Guix System 配置

> 从 NixOS 配置转换而来的 Guix System 参考实现。

## 目录结构

```
guix/
├── hosts/
│   └── workstation.scm    # 工作站主配置（单体式）
├── modules/               # 模块化配置（研究用，未在主配置中启用）
│   ├── base.scm           # 基础系统配置
│   ├── fonts.scm          # 字体配置
│   ├── desktop.scm        # 桌面环境配置
│   └── dev.scm            # 开发工具配置
└── README.md              # 本文件
```

## 快速开始

```bash
# 1. 修改 hosts/workstation.scm 中的文件系统配置
#    - (file-system-label "my-root") → 你的根分区标签或 UUID
#    - (file-system-label "ESP")     → 你的 EFI 分区标签或 UUID

# 2. 测试配置语法
guix system reconfigure --dry-run hosts/workstation.scm

# 3. 应用配置
sudo guix system reconfigure hosts/workstation.scm
```

## NixOS ↔ Guix 概念对照

| NixOS | Guix System | 说明 |
|-------|-------------|------|
| `flake.nix` | 无直接对应 | Guix 使用 SCM 文件直接声明 |
| `nixosConfigurations.foo` | `(operating-system ...)` | 系统声明 |
| `imports = [...]` | 无内置模块系统 | 需用 `(load "path.scm")` 或 `(include ...)` |
| `{ pkgs, ... }:` | `(use-modules (gnu packages ...))` | 包导入 |
| `environment.systemPackages` | `(packages (list ...))` | 系统包列表 |
| `fonts.packages` | `(packages (list font-...))` | 字体也是普通包 |
| `fonts.fontconfig.conf` | `/etc/fonts/local.conf` (via `etc-service-type`) | fontconfig 配置 |
| `services.*` | `(modify-services %desktop-services ...)` | 服务配置 |
| `boot.loader.systemd-boot` | `grub-efi-bootloader` | Guix 默认用 GRUB |
| `networking.networkmanager.enable` | `network-manager-service-type` | NetworkManager |
| `services.pipewire` | `pipewire-service-type` | PipeWire 音频 |
| `system.stateVersion` | 无 | Guix 无此概念 |
| `nixpkgs.config.allowUnfree` | 无 | Guix 默认为自由软件 |
| `home-manager` | `guix home` | 用户级配置 |

## 字体配置说明

### NixOS 中有但 Guix 主仓库没有的

| NixOS 包 | Guix 状态 | 替代方案 |
|----------|-----------|----------|
| `nerd-fonts.jetbrains-mono` | ❌ 不存在 | 手动下载到 `~/.local/share/fonts/` |
| `nerd-fonts.monaspace` | ❌ 不存在 | 同上 |
| `lilex` | ❌ 不存在 | 用 `font-dejavu` 替代 |

### Guix 可用的字体包

```scheme
font-dejavu        ;; DejaVu 字体（等宽 + Nerd 风格）
font-noto          ;; Noto 字体家族
font-noto-cjk      ;; Noto CJK（中日韩）
font-noto-emoji    ;; Noto Color Emoji
font-jetbrains-mono ;; JetBrains Mono（非 Nerd 版）
```

### Nerd Fonts 手动安装

```bash
# 下载 Nerd Font 并安装到用户目录
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
unzip JetBrainsMono.zip
fc-cache -fv
```

## 模块化 vs 单体式

### 当前实现：单体式 (workstation.scm)

所有配置写在一个文件中，适合作为学习参考。

### 模块化方案 (modules/*.scm)

Guix 没有 NixOS 那样内置的模块系统（`imports`），但可以用以下方式实现类似效果：

```scheme
;; 方案 1: load（在 REPL 或文件顶部）
(load "modules/base.scm")

;; 方案 2: include（在 operating-system 内）
(operating-system
  (include "modules/base.scm"))

;; 方案 3: 使用 (gnu services) 的 service-extension 机制
;; 这是 Guix 原生的模块化方式，但更复杂
```

## 需要手动调整的部分

1. **文件系统** (`%file-systems`): 修改为你的实际分区
2. **交换空间** (`%swap-devices`): 按需添加
3. **用户** (`%user-account`): 修改用户名和组
4. **字体**: Guix 没有 Nerd Fonts，需手动安装
5. **Hyprland**: Guix 有 `hyprland` 包，但没有直接的 service-type，需配置 XDG session
6. **非自由软件**: Guix 默认只包含自由软件，需自行添加渠道

## 常用命令

```bash
# 查看可用服务类型
guix system search desktop

# 查看可用字体包
guix search font | grep name

# 列出当前系统服务
guix system list-generations

# 回滚到上一代
sudo guix system switch-generation -1

# 查看配置差异
guix system diff generations
```
