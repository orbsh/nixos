# Orbit 蓝牙问题处理方案 (MT7925)

本目录记录 orbit 主机的 **MediaTek MT7925 组合芯片蓝牙部分故障**的诊断结论与处理流程。

## 硬件背景

- 网卡：MediaTek MT7925 (无线 `14c3:7925`)，WiFi(PCIe `mt7925e`) + 蓝牙(USB `0489:e111`) 组合芯片。
- WiFi 与蓝牙是**同一颗芯片**的两个接口：WiFi 走 PCIe，蓝牙走板载 USB。
- 相关配置：
  - `wifi-mt7925.nix` — **生效中**。修复 mt7925e 的 PCIe ASPM 在 suspend/resume 后的链路退化（与蓝牙无关）。
  - ~~bluetooth-retry.nix~~ — **已停用**（在 `hosts/workstations/default.nix` 中注释掉，不 import）。

## 故障现象

`bluetooth.service` 为 `inactive (dead)`，systemd 因 `ConditionPathIsDirectory=/sys/class/bluetooth` 不满足而**主动跳过启动**。
`/sys/class/bluetooth/` 不存在，蓝牙设备未参与 USB 枚举。

## 诊断结论

### 芯片在，但被 xHCI 拒绝枚举

尽管 `/sys/class/bluetooth` 为空，内核 dmesg 显示蓝牙曾尝试枚举但失败：

```
usb 3-5: device descriptor read/64, error -71
usb 3-5: device not accepting address 5, error -71
usb 3-5: WARN: invalid context state for evaluate context command.
usb usb3-port5: unable to enumerate USB device
```

`error -71` = 协议超时（EPROTO），`invalid context state` = xHCI 上下文状态异常。
**蓝牙芯片本身存在（硬件没坏），是组合芯片的蓝牙接口在枚举阶段与 xHCI 握手失败。**

### 已排除的因素

| 手段 | 结果 | 结论 |
|------|------|------|
| `modprobe -r xhci_pci; modprobe xhci_pci`（全套 USB 栈重建） | 蓝牙 3-5 重试仍报相同的 `error -71` + `invalid context state` | **排除 xHCI 控制器自身状态卡死** → 卡点在蓝牙芯片接口/固件层 |
| 端口级复位（`authorized` 切换 / uhubctl） | 失败端口无 device node，无法操作 | 失败枚举的设备内核不建 node，此路不通 |
| 旧 `bluetooth-retry.nix` 自动重试 | 反复 remove/rescan 控制器 + reload mt7925e 均无效 | **已停用**——remove/rescan 触不到芯片固件卡死点；rmmod mt7925e 只影响 WiFi 的 PCIe 部分，与蓝牙 USB 部分无关 |

### 关键判断

- **升级内核(6.18.45→6.18.48)前就已发生故障** → 不是内核回归。
- 全套 xHCI 栈重建仍失败，且 `invalid context state` 表明卡点在**芯片固件层**，而非主板控制器。
- 因此最有可能是 MT7925 蓝牙接口**固件死锁**。

## 处理步骤（按顺序执行）

### 1. 整机彻底断电（首选，用于排除固件死锁）

芯片固件层卡死通常连 OS 重启都不够，需要**真正切断所有电源**让电容放电：

1. 正常关机（系统能优雅关闭就正常关）。
2. **拔掉 AC 电源线**（若从内置电池供电，卸下电池最彻底）。
3. **等待 30~60 秒**让主板电容放电干净（关键步骤——等放电，不是关机后立刻开机）。
4. 重新接上电源 → 开机。

> 注意：长按电源键是「运行中强制断电」，只在系统已死机无法正常关机时用；**关机状态下长按没有意义**。断电复位的核心 = 断开一切电源 + 等待电容放电。

### 2. 验证

```bash
# 蓝牙设备是否被枚举
ls /sys/class/bluetooth/ 2>&1        # 非空 = 成功

# 控制器状态（成功时 active）
systemctl status bluetooth --no-pager

# 蓝牙是否出现
bluetoothctl devices
```

成功标志：`/sys/class/bluetooth` 出现内容，`bluetooth.service` 变 active。

### 3. 若断电重启后仍不枚举

说明不是简单固件死锁恢复，需回到 MT7925 蓝牙不枚举的已知问题（升级内核前已存在）继续排查——可能方向：
- 主板 BIOS / 固件层面禁用或异常；
- 板载 USB 端口供电/信号完整性问题（`error -71` 的硬件侧原因）；
- 该芯片在特定枚举时序下的已知缺陷（曾有 `bluetooth-retry.nix` 尝试缓解，但效果有限已停用）。

## 备注

- `bluetoothctl` 在无控制器时会**阻塞卡住**，排查时用 `timeout 5 bluetoothctl ...` 避免挂死。
- 本方案聚焦**运行时/硬件层处置**；如最终定位到配置层根因，应在本目录补配置模块并在本 README 更新。