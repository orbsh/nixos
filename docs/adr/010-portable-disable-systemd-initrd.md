# ADR-010: Portable USB 系统盘禁用 systemd initrd

**日期**: 2026-06-10
**状态**: 已采纳

### 问题

Portable 作为 USB 移动系统盘，启动时多个服务无限等待设备就绪，无法正常引导。

### 历史背景

| 提交 | 变更 | 结果 |
|------|------|------|
| `18806ac` | 添加 `thunderbolt`、`usbhid`、`sdhci_pci` 内核模块到 `boot.initrd.availableKernelModules` | ✅ USB 启动问题修复 |
| `44da8c8` | 启用 `boot.initrd.systemd.enable = true` | ❌ 问题复发，服务无限等待 |
| 当前 | 注释掉 `boot.initrd.systemd.enable`，使用传统 stage-1 init | ✅ 问题解决 |

### 根因分析

USB 硬盘枚举过程较慢（USB 3.0 初始化、分区表读取），两种 initrd 的等待机制差异导致表现不同：

| 方面 | stage-1 init（传统） | systemd initrd |
|------|---------------------|----------------|
| 等待策略 | 阻塞等待，设备出现就继续 | 超时机制，超时后标记失败 |
| USB 枚举容忍度 | 高，天然适配慢设备 | 依赖 udev 事件，可能错过 |
| 依赖复杂度 | 线性脚本，简单可靠 | unit 依赖图，链条长，任一环节失败都会阻塞 |

systemd initrd 通过 udev 事件驱动设备发现。USB 设备枚举慢，udev 事件可能在模块加载完成后才触发，导致依赖链中的 `.device` unit 超时，进而阻塞所有依赖 `initrd-root-fs.target` 的服务 — 表现为"几个服务无限等待"。

固定磁盘（NVMe/SATA）场景下 systemd initrd 没有问题，因为设备出现很快。

### 决策

Portable 禁用 `boot.initrd.systemd.enable`，使用传统 stage-1 init 脚本：

```nix
# hosts/portable/hardware-configuration.nix
# 注意：portable 作为 USB 移动系统盘，必须禁用 systemd initrd。
# 原因：USB 设备枚举慢，systemd initrd 的 udev 事件驱动机制可能错过设备就绪信号，
# 导致 .device unit 超时，阻塞所有依赖 initrd-root-fs.target 的服务。
# stage-1 init 的阻塞等待机制天然适配慢速 USB 设备。
# （commit 44da8c8 曾启用此项导致启动失败，详见 ADR-010）
boot.initrd.systemd.enable = false;
```

### 后果

nixpkgs 中 `boot.initrd.systemd.enable` 默认值为 `true`。仅 portable 显式设为 `false`。

| 主机类型 | systemd initrd | 理由 |
|----------|---------------|------|
| workstations | ✅ 默认 `true` | 固定 NVMe/SATA 磁盘，无问题 |
| server | ✅ 默认 `true` | 固定磁盘，无问题 |
| portable | ❌ 显式 `false` | USB 移动设备枚举慢，stage-1 更可靠 |
| qemu | ✅ 默认 `true` | 虚拟磁盘，无问题 |
| k8s 集群 | ✅ 默认 `true` | 固定磁盘，无问题 |

### 理由

1. **场景适配** — USB 移动设备枚举慢，stage-1 init 的阻塞等待天然适配
2. **已验证** — 禁用后 portable 可正常启动，其他 hosts 均未显式覆盖
3. **风险最低** — stage-1 init 逻辑简单，不引入额外的 unit 依赖链复杂性

### 关于 scripted initrd deprecation warning（2026-06 补充）

NixOS 26.05 起，`boot.initrd.systemd.enable = false` 会触发 deprecation warning（26.11 移除 scripted initrd）。

**决策：保持现状，忽略 warning。**

| 因素 | 评估 |
|------|------|
| 稳定性 | portable 是维护/救援用途，稳定性优先于消除 warning |
| 修复成本 | 需物理接入测试（USB 盘无法远程修复），成本高 |
| 时间线 | 26.11（约 2026-11）才真正移除，还有 5 个月缓冲 |
| 替代方案 | 可尝试 `x-systemd.device-timeout` 延长等待，但需实测验证 |

**触发条件**：当以下任一条件满足时，重新评估迁移到 systemd initrd：
1. NixOS 26.11 发布，scripted initrd 被移除
2. 上游提供 USB 设备枚举的可靠解决方案
3. portable 的 USB 硬件升级（枚举速度不再成为瓶颈）
