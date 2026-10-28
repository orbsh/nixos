# NixOS Configuration

> 基于 NixOS unstable 的模块化 Flakes 配置，采用 **域（Domain）→ 预设（Profile）→ 桌面预设（Desktop Preset）** 三层架构。

---

## 🏗 架构概览

```
flake.nix              ← Flake 入口，自动发现 hosts/ 下的域
  └── hosts/<domain>/  ← 域定义（workstations/k8s-dev/portable/qemu/server...）
        └── profiles/<profile>.nix  ← 系统预设（workstation/server/portable/qemu）
              └── modules/desktop/<preset>.nix  ← 桌面预设（mini/base/full）
                    └── modules/desktop/units/*.nix  ← 桌面组件单元
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



## 🧱 模块组织：三种形状

统一机制：`modules/<dir>/units/*.nix` = **原子单元**；`modules/<dir>/*.nix`（顶层）= **聚合器**（组合 units）。按聚合器间的组织关系分三种：

**① 链式（层级式）—— 聚合器互相 import，层层叠加**：`desktop/`（`mini ⊂ base ⊂ full`）、`system/`（`core ⊂ extra`）。每层只声明增量，引最外层即得整链，公共层在根定义后由后层继承。

**② 预聚合 flavor（选一）—— 并列、互不重叠、引一个**：`dev/`（fullstack / rescue / server，见 `profiles/*.nix`）。各 flavor 聚合器并列，共用 `dev/units/`，每套是一份完整选配，host 按其角色引其中一个，不引多个。（`dev/` 下的 backend / data-science / infrastructure 是占位聚合器——骨架保留、未接入任何 profile，仍在活跃树内。）

**③ 单元式（逐个）—— 自包含模块，含自身依赖，按需独立 import**：`services/`（coredns / harmonia / gitea / miniflux / qbittorrent / rustfs / virt …）。每个服务是自包含单元，连自己的网络/依赖一起（如 gitea 为 `imports = [ ./podman/network.nix ./podman/gitea.nix ]`，引用 podman 内多个基础设施）；`podman/` 是共享容器基础设施（app-net 网络 + 各应用 pod），非独立服务，由外层服务单元引用。逐个独立引入。

> 判断：被其他聚合器 `import` 成链 → **①**；并列可互换的完整选配、引一个 → **②**；独立自包含能力、逐个引 → **③**。

**禁用模块**：不再引入的模块统一移入 `modules/legacy/`（按原相对路径存放，不做任何 import 源），保留备查。聚合器里原本指向它们的注释行已改指 legacy 路径，取消注释 + 把文件移回原位即可启用——见 `modules/legacy/README.md`。

---

## 🖥 桌面预设层级

层级式：`mini ⊂ base ⊂ full`，每层只声明增量，逐层叠加。

| 预设 | 相对 | 增量 |
|------|------|------|
| `mini`（QEMU） | 层级根 | apps-core, de-session（桌面子系统）, greetd, 输入法, 字体, 无障碍, qutebrowser, rbw |
| `base`（便携） | = mini + 增量 | apps-extra, rime |
| `full`（工作站） | = base + 增量 | apps-im, laptop, networkmanager, walker, wl-clipboard |

**设计原则**：逐层 `import`（`base` imports `mini`，`full` imports `base`），每层只声明自己的增量，公共层在 mini 定义后继承。桌面子系统（`cosmic` / `niri` 及 DE→组件关联表）统一收敛于 `units/de-session/`；`hyprland` / `quickshell` / `eww` / `vicinae` 当前未引入，已移入 `legacy/`。

**DE 模型**：纳入由 imports 决定（引 de-session = 装桌面子系统），运行时由 dispatcher 检测活跃会话（cosmic/hyprland）拉起对应 target，组件（quickshell→hyprland、eww→cosmic）只挂自己 DE 的 target，绝不挂 graphical-session.target。切换 DE = 登录选会话，不 rebuild。

### 桌面单元（units）

| 单元 | 用途 |
|------|------|
| `de-session/` | **桌面子系统**：`default`（DE 层：dispatcher + DE→组件关联表）+ `cosmic` + `niri`（`hyprland` / `quickshell` / `eww` / `vicinae` 已移入 legacy） |
| `greetd.nix` | greetd 登录管理器（会话选择 + 记忆） |
| `input-method.nix` | fcitx5 中文输入法 |
| `fonts.nix` | 字体配置 |
| `accessibility.nix` | 无障碍支持 |
| `apps-core.nix` | 核心应用（终端、编辑器、浏览器基础、媒体工具） |
| `apps-extra.nix` | 额外应用（办公、阅读、创作工具） |
| `apps-im.nix` | 即时通讯应用 |
| `laptop.nix` | 笔记本电源管理 |
| `networkmanager.nix` | 网络管理 |
| `rime.nix` | Rime 输入法（NixOS 级模块） |
| `qutebrowser.nix` | qutebrowser 浏览器 |
| `walker.nix` | walker 启动器（备选，不常用） |
| `home-terminals.nix` | 终端配置（ghostty + alacritty + zellij） |
| `home-xdg.nix` | XDG 配置（mimeApps + userDirs + BROWSER） |

---

## 📋 Host 加载路径

### 1. Workstations（orbit / team-alice / team-bob）

```
hosts/workstations/default.nix          # 域名 workstations，节点表 { orbit, team-alice, team-bob }
  ├── 域级 imports: profiles/workstation.nix     # 自动合并到所有成员节点
  └── orbit（成员示例）
        ├── profiles/workstation.nix
        │     ├── modules/system/extra.nix        (core ⊂ extra：sys/kanata/base/nix/gc/users/network/container/nushell/hardware + HM home-*)
        │     ├── modules/dev/fullstack.nix       (python/rust/javascript/haskell/k8s/wasm/data-tools/net-tools/jcode)
        │     ├── modules/desktop/full.nix        (base ⊂ full：mini + apps-extra + rime + apps-im/laptop/networkmanager/walker/mudra)
        │     ├── modules/services/virt.nix       (libvirtd/virt-manager)
        │     ├── modules/services/hermes-system.nix
        │     ├── modules/services/harmonia.nix   (本地二进制缓存 :5100)
        │     ├── modules/services/rustfs.nix
        │     ├── modules/services/singbox.nix    (代理组件，:7890)
        │     ├── modules/services/gitea.nix / miniflux.nix / qbittorrent.nix
        │     ├── modules/services/ferron.nix     (文件下载 + CGI 网关，:8080)
        │     └── modules/services/numa.nix       (本地 DNS + 反代，工作站专用)
        ├── ./orbit/{hardware,disk,wireguard,wifi-mt7925,netbird,intranet-dns}.nix
        ├── ./wanxiang.nix        (RIME 万象模型源：url + flat hash)
        ├── ./nushell.nix         (nushell 预编译二进制源：url + flat hash)
        ├── ./herdr.nix           (herdr 预编译二进制源：url + flat hash)
        └── libs/registries-gen.nix   (容器 registry 配置生成)

节点级覆盖（写在 orbit 块内）：rime.wubi.localPath、services.singbox.{configDir,ruleDir}、services.ferron.dataDir
team-alice / team-bob：仅 disko + 各自 hardware.nix（域级 profile 同样生效）
```

**桌面子系统**：`desktop/{mini ⊂ base ⊂ full}`；DE 与组件统一收敛于 `modules/desktop/units/de-session/`（当前启用 `cosmic`、`niri`）。未启用的 `hyprland` / `quickshell` / `eww` / `vicinae` 在 `modules/legacy/`。

---

### 2. Portable（便携系统盘）

```
hosts/portable/default.nix
  ├── profiles/portable.nix
  │     ├── modules/system/core.nix        (核心系统 + Home Manager)
  │     ├── modules/dev/rescue.nix
  │     ├── modules/desktop/base.nix       (mini + apps-extra + rime-pinyin/rime-wubi)
  │     ├── modules/services/singbox.nix
  │     └── modules/services/ferron.nix
  ├── ./disk.nix, ./hardware-configuration.nix
  └── modules/services/harmonia.nix, modules/services/hermes-system.nix   (节点级单独引入)
```

**与 workstation 的区别**：
- 无 `dev/fullstack.nix`（无开发工具链），改引 `dev/rescue.nix`
- 用 `base.nix` 而非 `full.nix`（无 apps-im / laptop / networkmanager / walker / mudra）
- 移动盘：`boot.loader.efi.canTouchEfiVariables = false`（避免写到宿主机 EFI）
- 启用 `udisks2`（可移动设备自动挂载）与 `getty.autologinUser`
- nushell `developMode = false` → 经 flake input 部署（详见 [ADR-003](docs/adr/003-nushell-version-develop-mode.md)）

---

### 3. QEMU（虚拟机）

```
hosts/qemu/default.nix
  └── profiles/qemu.nix
        ├── disko.nixosModules.disko
        ├── modules/system/core.nix
        ├── modules/desktop/mini.nix      (COSMIC + greetd + 输入法/字体/无障碍)
        ├── modules/dev/server.nix
        ├── modules/services/singbox.nix
        └── modules/services/ferron.nix
      ./disk.nix, ./hardware-configuration.nix（由 hosts/qemu/default.nix 引入）
```

**特殊配置**：`services.spice-vdagentd`（剪贴板/分辨率自适应）；`greetd.settings.initial_session` 直接进 `cosmic-session`；用户初始密码为空（免密自动登录）。

---

### 4. Server（独立服务器）

```
hosts/server/default.nix
  ├── profiles/server.nix
  │     ├── modules/system/core.nix        (核心系统 + Home Manager)
  │     ├── modules/dev/server.nix         (服务器开发工具)
  │     ├── modules/services/virt.nix      (libvirtd/virt-manager)
  │     ├── modules/services/harmonia.nix  (本地二进制缓存 :5100)
  │     ├── modules/services/singbox.nix
  │     └── modules/services/ferron.nix
  └── ./hardware/*, ./netbird.nix
```

**特点**：无桌面环境，headless；`nix.gc.keepGenerations = 20`（按代保留，完整回滚）；关闭 HM 的 `programs.neovim`（nvim 由系统级提供，插件走 lazy.nvim）。

---

### 5. K8s 集群（k8s-dev / k8s-small / k8s-nscc / k8s-large）

K8s 节点通过 `modules/k8s/k8s-libs.nix` 的 `expandCluster` 函数构建，自动注入：

```
modules/k8s/k8s-libs.nix → expandCluster → buildNode
  ├── profiles/server.nix           ← 所有节点自动继承（imports = [ profiles/server.nix ] ++ ...）
  ├── k8sRoleModules                ← control / worker / combo 角色模块
  │     ├── control: k8s-control.nix
  │     ├── worker: k8s-worker.nix
  │     └── combo: k8s-control.nix + k8s-worker.nix + 移除 taint
  ├── clusterModules                ← 域级共享模块（如 registries-gen）
  ├── runtimeModules                ← crio / containerd
  ├── k8s 配置模块                  (kubernetes、apiserver SANs、cert sync；k8s-common.nix 内引 dev/server.nix)
  └── node.imports                  ← 节点特有导入（硬件、wireguard、netbird 等）
```

**证书管理**：证书权限 0600，kubeconfig 通过脚本自动生成。详见 [ADR-013: K8s 证书管理](docs/adr/013-k8s-certificate-management.md)。

**k8s-dev/dxserver 示例**：
```
hosts/k8s-dev/default.nix
  └── nodes.dxserver
        ├── profiles/server.nix           (自动注入)
        │     ├── modules/system/core.nix
        │     ├── modules/dev/server.nix
        │     ├── modules/services/virt.nix
        │     └── modules/services/harmonia.nix
        ├── k8s-role: combo               (control + worker 合一)
        ├── runtime: containerd
        ├── server/hardware/disk.nix
        ├── server/hardware/hardware-configuration.nix
        ├── server/hardware/wireguard.nix
        ├── server/netbird.nix
        └── modules/services/coredns.nix    (内网 DNS)
```

---

### 6. ISO（nixos-anywhere 专用 Live 镜像）

```
flake.nix → .#iso （nixosSystem，specialArgs 注入 my-* 配置源）
  └── profiles/iso/default.nix
        ├── nixpkgs iso-image.nix        ← 最小 ISO 构建器（不依赖 installation-cd-minimal）
        ├── disko.nixosModules.disko + home-manager.nixosModules.home-manager
        ├── modules/system/units/nix.nix         ← Nix 生态工具（nh, nixos-anywhere 等）
        ├── modules/system/units/home-nvim.nix   ← Neovim（系统级，HM 模块关闭）
        ├── modules/system/units/home-helix.nix  ← Helix 主题 + LSP + 快捷键
        └── modules/system/units/home-git.nix    ← Git 配置（用户名/邮箱）
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

## 🛠 脚本书写原则

nixos 项目中的脚本，语言优先级：

- **优先 Python** —— 通用性强、生态好，且 Python 是必备基础组件（包括服务器端）。
- **交互优先 Nushell** —— 用户可能直接调用的命令可用 Nushell，交互／自动补全体验更好。
- **尽量避免 Bash** —— 仅在短胶水／辅助片段保留 bash（如 Nix 构建期未声明 python 依赖时，默认 shell 即为 bash）；用户态脚本不以 bash 实现。

## 🔧 上游版本维护（手动维护版不能自动跟 nixpkgs 的包）

集中在这两个文件：清单 `scripts/upstream.yml`（每个包的上游来源、当前版本、需要改写的站点文件与锚点）+ 工具 `scripts/upstream.nu`。

```sh
nu scripts/upstream.nu check [name]    # release/doc：上游最新 tag vs 清单 current
nu scripts/upstream.nu audit [name]    # mirror：box.d 本地文件 hash vs Nix 文件里记录的值
nu scripts/upstream.nu fetch <name>    # 按 upstream 模板下载镜像文件到 dest（缺文件时）
nu scripts/upstream.nu hash  <name>    # 打印本地文件的 hash
nu scripts/upstream.nu bump  <name> [--to V] [--write]   # 默认 dry-run，--write 才落盘
```

三类来源与 hash 约定（对应该包在 Nix 侧的消费方式）：

| 场景 | Nix 侧消费 | hash 算法 |
|------|-----------|-----------|
| `fetchurl`（GitHub release 资产） | `pkgs.fetchurl { url; hash; }` | `nix hash file`（flat） |
| box.d 单文件 / 模型（旧约定，仅 rime-wubi 的 git 源仍在用） | `builtins.fetchTree { type = "file"; narHash; }` | `nix hash path`（单文件 NAR） |
| box.d 单文件 / 模型（现行约定，可随闭包推送） | `pkgs.fetchurl { url; hash; }` | `nix hash file`（flat SRI） |
| box.d 上的 tarball | 直接用 `pkgs.fetchurl`（stdenv 解包；无顶层目录时 `sourceRoot = "."`） | `nix hash file`（flat SRI） |

- `release` 类的 ferron / rustdesk / trunk 在 derivation 上挂了 `passthru.updateScript`，指向 `upstream.nu bump <name> --write`（按 nixpkgs 约定；这两个脚本文件被 git 跟踪后 flake 才认）。
- GitHub 取最新 tag 与下载资产走清单里的 `settings.proxy`（本机 7890）。
- 工具自身支持从子目录或仓库外调用（先看 `$env.UPSTREAM_REPO`，再从 cwd 向上找 `scripts/upstream.yml`）。
- **替换同名镜像文件后构建可能仍命中旧内容**：nix 的 fetcher cache 按 URL 记录，URL 不变（文件名不含版本，如 numa）时会沿用缓存结果，报 NAR hash mismatch。用 `nix build --refresh`（或 `--option tarball-ttl 0`）取新内容；文件名带版本号的条目（如 nushell 的 `nu-{v}-…`）换 URL 后天然避开。

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
│   ├── k8s-small/                # K8s 小集群
│   ├── k8s-nscc/                 # K8s NSCC 集群
│   └── k8s-large/                # K8s 大集群
├── modules/                      # 可组合构建块
│   ├── system/                   # 系统级模块
│   │   ├── core.nix              # 核心预设（sys, base, nix, users, network, extra, container + Home Manager 聚合）
│   │   ├── extra.nix             # 工作站扩展工具
│   │   ├── assets/               # 共享资源（zellij 配置、证书等）
│   │   └── units/                # 系统单元 + HM 单元（home-*.nix）
│   ├── desktop/                  # 桌面预设
│   │   ├── mini.nix              # 最小桌面（QEMU）
│   │   ├── base.nix              # 基础桌面（portable）
│   │   ├── full.nix              # 完整桌面（base + apps-im/laptop/networkmanager/walker 增量）
│   │   └── units/                # 桌面组件单元 + HM 单元（home-terminals, home-xdg）
│   ├── dev/                      # 开发工具模块
│   │   ├── server.nix            # 服务器开发工具
│   │   ├── fullstack.nix         # 全栈开发工具
│   │   ├── rescue.nix            # 救援工具
│   │   └── units/                # 各语言/工具单元
│   ├── k8s/                      # Kubernetes 集群模块（配置 + 展开逻辑）
│   │   ├── k8s-libs.nix          # 集群展开（flake.nix 直接消费）
│   │   ├── k8s-common.nix        # CRI-O/Containerd 公共部分
│   │   ├── k8s-control.nix       # 控制平面
│   │   ├── k8s-worker.nix        # 工作节点
│   │   ├── k8s-addons.nix        # 集群组件（flannel, metrics-server 等）
│   │   ├── cert-manager.nix
│   │   ├── containerd.nix / crio.nix
│   │   ├── envoy-gateway.nix     # istio-gateway 已移入 legacy（两者互斥）
│   │   └── assets/               # K8s 资源清单 + 脚本
│   ├── services/                 # 系统服务模块
│   │   ├── virt.nix              # 虚拟机
│   │   ├── harmonia.nix          # 本地二进制缓存
│   │   ├── hermes-system.nix     # Hermes Agent
│   │   ├── numa.nix              # 本地 DNS + 反向代理
│   │   ├── rustfs.nix            # RustFS
│   │   ├── coredns.nix           # CoreDNS
│   │   └── podman/               # Podman 应用（gitea, mihomo, qbittorrent, miniflux 等）
│   └── legacy/                   # 未启用模块存放区（已废弃/被替代/暂时禁用；镜像原相对路径，见其 README）
└── profiles/                     # 入口（被 flake.nix 或 hosts/ 消费）
    ├── portable.nix              # 便携系统预设
    ├── qemu.nix                  # QEMU 虚拟机预设
    ├── server.nix                # 服务器预设
    ├── workstation.nix           # 工作站预设
    └── iso/                      # nixos-anywhere 专用 Live ISO（~781MB）
        └── default.nix           # ISO 入口（flake.nix 直接消费）
```

---

## 🔀 Overlay 策略

本项目采用**选项驱动 overlay 架构**：模块内聚在 `modules/*/units/` 中，host 文件只设选项值。详见 [ADR-002: Overlay by Domain](docs/adr/002-overlay-by-domain.md)。

### 核心原则

**模块定义逻辑（`modules/`），host 文件只设选项值（`hosts/`）。**

所有 overlay 模块统一放在 `modules/*/units/` 中，由 `profiles/*.nix` 统一引入。host 文件只负责设置选项值，不碰逻辑。

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

#### DNS 链路（有宿主机 CoreDNS）

```
Pod 查询外部域名
  → kube-dns ClusterIP (10.0.0.254)
  → 集群内 CoreDNS pod
  → Corefile: forward . <cni0IP>
  → 宿主机 CoreDNS（通过 cni0 网桥可达）
  → 宿主机 CoreDNS forward 到上游公共 DNS
```

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

### Nix Substituter 配置

全局可变配置（substituters、公共 DNS）统一在 `flake.nix` 的 `commonArgs` 中定义，模块通过函数参数消费。详见 [ADR-017: 全局可变配置归属 flake.nix](docs/adr/017-global-config-in-flake.md)。

#### 配置位置

| 配置项 | 文件 | 说明 |
|--------|------|------|
| substituters + trusted-public-keys | `flake.nix` | `commonArgs.nixSubstituters` |
| nix.settings 消费 | `modules/system/units/nix.nix` | 通过函数参数注入 |
| 本地 Harmonia 缓存追加 | `hosts/workstations/harmonia-cache.nix` | NixOS 模块系统自动合并 |
