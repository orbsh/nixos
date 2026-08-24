# sing-box 可复用代理组件（替换 mihomo/ladder）方案

> **状态**: 方案草稿（待推敲，明天继续）
> **创建时间**: 2026-08-24
> **目标**: 用轻量 sing-box 组件替换 mihomo/ladder，配置声明式进 NixOS，工作站走代理、服务器全直连占位，并根治"网络切换后需手动重启"的痛点

---

## 一、背景与痛点

现有代理架构（workstation/portable）：

- `modules/services/ladder.nix` → mihomo（podman 容器，端口 7890/7891/9090）
- mihomo 配置在 **NixOS 配置系统外**：`${dataDir}/ladder/mihomo/config.yaml`（非 store symlink，可手改）——即"配置在外面，比较重"
- **rule-set 分流体系**（config.yaml 现况）：
  ```
  private→DIRECT, china→DIRECT, world-high→bigme, cloudflare→cloudflare,
  world→bigme, GEOIP CN→DIRECT, 兜底→bigme
  ```
  - rule-providers: mojie/world/world-high/china/private/cloudflare（`type: file`，读 `rules/*.yaml`）
  - proxy-providers: bigme/mojie/daxun/wh/cloudflare/hysteria2/lan（读 `proxies/*.yaml` 订阅）
- 上游出口形态：**不加密的简单 SOCKS5/HTTP server**（用户确认）

需替换的原因：
1. mihomo 重、配置在配置系统外、只有 workstation 有（服务端部署麻烦）
2. 曾用 sing-box 时有一个痛点：**切换网络后不自动重连，经常需手动重启**

## 二、目标

1. 配置全部声明式进 NixOS，摆脱 config.yaml 在系统外
2. 混合模式：本地 `127.0.0.1:7890` 混合入站(HTTP+SOCKS5)，路由规则分流（走代理 / 直连）
3. 可复用：工作站=真实代理，服务器=全直连占位（同模块、同端口、同服务，仅上游数据不同）
4. 网络切换自动重连：systemd 监听网络事件 + 健康检查兜底，根治手动重启

## 三、组件设计

**文件**: `modules/services/singbox.nix`（服务层，工作站/服务器都能引，非桌面层）

```nix
{ config, pkgs, lib, ... }: {
  options.services.singbox = {
    enable = lib.mkOption {
      type = lib.types.bool; default = false;
    };
    listenPort = lib.mkOption {
      type = lib.types.int; default = 7890;   # 兼容现有 http_proxy 应用
    };
    upstream = lib.mkOption {                 # 明文 socks 出口；null=全直连占位
      type = lib.types.nullOr lib.types.str;
      default = null;                          # 服务器留 null
    };
    proxyDomains = lib.mkOption {             # 走代理的域名规则集
      type = lib.types.listOf lib.types.str;
      default = [];
    };
    healthUrl = lib.mkOption {                # 探活地址（健康检查重启用）
      type = lib.types.str;
      default = "http://www.gstatic.com/generate_204";
    };
  };
}
```

## 四、行为模式（“检测目录有数据”）

| | 工作站 | 服务器 |
|---|---|---|
| `upstream` | `socks5://<出口>:<port>` | `null` |
| `proxyDomains` | 有数据（走代理规则集） | `[]` |
| 出站 | `proxy→socks上游 / direct→直连` | 仅 `direct` |
| 路由规则 | `proxyDomains→proxy，其余/私有→direct` | 全→direct |
| 结果 | 混合模式（代理+直连） | 全直连占位（同端口，应用层无需改） |

应用层 `http_proxy=127.0.0.1:7890` 两端一致；服务器将来补上游数据即无缝升级为代理。

## 五、网络切换自动重连（双层）

**为什么 sing-box 内建解决不了**：socks 出站 + 常驻，网络切换（Wi-Fi→有线、换热点、VPN 断开）后，sing-box 的**已连接隧道、DNS 解析缓存、路由表全停留在切换前**——它没有"网络已变化，重建隧道"的自我感知。这是 sing-box 公开已知痛点（GitHub issues：WireGuard 断网不重连 #2863/#1415、网络切换 #342），**非配置能弥补**。

**层1 — NetworkManager dispatcher**（catch 主动切换）：
- 触发：网络 `up/down/vpn-up/vpn-down` → `systemctl restart singbox.service`
- 声明式：`systemd.services.NetworkManager.dispatcherScripts`

**层2 — 健康检查 timer**（catch 漏网：静默断链/上游无响应）：
- 每 2 分钟 curl `healthUrl`，连续失败 → `systemctl restart singbox.service`
- 用 `systemd.timers` 声明式

## 六、文件规划

| 文件 | 内容 |
|------|------|
| `modules/services/singbox.nix` | 组件（选项 + systemd 服务 + dispatcher + timer） |
| `hosts/workstations/nix-proxy.nix` | 工作站设 `upstream` + `proxyDomains`（替代现有 mihomo 那行） |
| 服务器 host | `services.singbox.enable = true;`（其余默认 = 占位） |
| `modules/services/ladder.nix` | **保留不动**（mihomo 作对照，确认切换后再清） |

## 七、待推敲细节（明天逐条打磨）

1. **"切换网络"语义确认**：按网络切换（Wi-Fi↔有线/换热点）理解，确认后调整 dispatcher 触发条件；若含"切换代理订阅节点"则另一回事
2. **rule-set 迁移**：现 mihomo 的 `rules/china.yaml`/`world.yaml` 是否沿用 → 决定 `proxyDomains` 来源（手写列表 or 生成）
3. **上游出口具体地址**：`socks5://<ip>:<port>` 形态
4. **透明接管 vs 应用感知**：本方案用应用感知(显式 http_proxy)；如要透明接管再加 nftables/tun（用户此前倾向不需要）
5. **dispatcher 重启防抖**：加抑制（如 10s 内只重启一次），避免网络事件风暴
6. **sing-box vs mihomo 语法映射**：rule-set/GEOIP 分流的 sing-box 等价表达（rule_set / geoip / ip_cidr），需验证配置文件生成逻辑
7. **健康检查 timer 的失败阈值**：连续几次失败才重启，避免误杀

## 八、待确认决策点（影响方向）

- 工作站是否唯一跑代理的机器、且走 NetworkManager（决定 dispatcher 是否够用；服务器是纯直连占位，理论上不需要重启逻辑）
- 上游出口是否存续/是否接受明文（不加密转发在不可信链路有中间人风险，需用户权衡）