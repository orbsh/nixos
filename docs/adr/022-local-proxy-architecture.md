# ADR-022: 本地代理服务架构（sing-box 组件 + 共享代理地址变量）

**日期**: 2026-08-25
**状态**: 已采纳
**涉及**: `modules/services/singbox.nix`、`modules/system/core.nix`、`modules/system/units/nix.nix`、`modules/desktop/units/de-session/vicinae.nix`、`flake.nix`
**取代**: `modules/services/ladder.nix`（mihomo/podman 容器方案，保留作对照，确认后清理）

### 问题

原代理架构存在三个问题：

1. **mihomo 重、配置在配置系统外** — `modules/services/ladder.nix` 用 podman 容器跑 mihomo，配置在 `${dataDir}/ladder/mihomo/config.yaml`（非 store symlink，可手改），且只有 workstation 有，服务端部署麻烦。
2. **sing-box 网络切换后不自动重连** — 曾用 sing-box 时切换网络后需手动重启（公开已知痛点，issue #2863/#1415/#342）。
3. **代理地址散落各处** — nix-daemon、vicinae 各自硬编码 `127.0.0.1:7890`，未来换代理服务（其他端口/远程/不同协议）要逐个改，且没有"未运行代理时自动直连"的兜底。

### 决策

**1. 用轻量 sing-box 组件替换 mihomo**，配置声明式进 NixOS，全 hosts 可复用：

- **系统级 service**（非 user service）——服务器无登录用户会话也能跑
- **引入即起效，无 `enable` 选项**——对齐仓库 service 组件范式（harmonia/gitea/virt 等皆无 enable，引入=启用）
- **单层配置目录** `~/.config/singbox/`，全用 `-C` 自动深度合并顶层 `*.json`
  - `config.json`（log/inbounds/outbounds[direct 兜底]/route 框架）
  - `outbounds.json`（出口扩展点，数组留空+注释）
  - `rules.json`（rule_set 声明扩展点）
- 只支持 **JSON/JSONC**（源码/CLI 实测 1.13.19：无 YAML/TOML 解析器）
- 配置目录指向 `$HOME`（非 store）→ 可手改，`systemctl reload singbox.service` 热更无需 rebuild
- **`ExecReload` 先 check 后 reload 两行守卫**：systemd 逐行执行 ExecReload 数组，行1 `sing-box check` 失败则整体失败不执行行2，旧进程继续（避免 check 失败空窗）
- 默认 **final=direct 全直连兜底**（无规则全直连）；要代理出口手改 `outbounds.json` 追加 + `rules.json` 引用 rule_set
- 各 profile 分别引入：workstation（6789 测试端口）、server/qemu/portable（默认 7890）

**2. 网络切换自动重连（双层）**——因为 sing-box 内建解决不了（socks 出站常驻，切换后隧道/DNS/路由停滞），配置非能力：

- **层1 NetworkManager dispatcher**：网络 `up/down/vpn-up/vpn-down` → `systemctl restart singbox.service`（catch 主动切换）
- **层2 健康检查 timer**：每 2 分钟 curl 探活，连续失败 → restart（catch 静默断链/上游无响应）

**3. 共享代理地址变量 `config.proxy.address`**（定义于 `modules/system/core.nix` 全 hosts 公共基座）：

- 类型 `nullOr str`，默认 `null`（= 不走代理，直连）
- singbox 引入时自动赋其完整地址：`proxy.address = mkDefault "http://127.0.0.1:<listenPort>"`
- nix-daemon、vicinae 从该变量派生 http_proxy，**为空时直连**
- 完整 URI 而非端口号 → 不局限于本机 singbox，可手动覆盖指向其他代理服务（`socks5://host:port` 等）
- 定义于 core.nix 使变量**独立于 singbox 存在**：不引 singbox 的机器天然直连，换代理只改这一处

**4. noProxy 白名单并入 `flake.nix` 的 `nixSubstituters`**（与 substituters 同层公共数据），不再作为 NixOS 选项：

- `nixSubstituters = { substituters, noProxy, trusted-public-keys }`
- nix.nix 从参数取：`no_proxy = lib.concatStringsSep "," nixSubstituters.noProxy`
- 镜像地址（ustc/tuna/sjtu）→ noProxy 直连；官网 cache.nixos.org → 走代理

### 结果

| 机器 | singbox | proxy.address | nix-daemon http_proxy |
|------|---------|---------------|------------------------|
| workstation | ✓（6789 测试端口） | `http://127.0.0.1:6789` | 跟随 |
| server | ✓ 全直连占位（7890） | `http://127.0.0.1:7890` | 跟随 |
| 不引 singbox | — | `null`（直连） | 不设 http_proxy |

**已删**: `hosts/workstations/nix-proxy.nix`（原显式设 7890，现由共享变量默认覆盖，冗余）

### 关键约束

- **sing-box 只支持 JSON/JSONC**，不支持 YAML/TOML；配目录 `-C` 只认 `.json` 非递归子目录
- **数组追加非覆盖**：想覆盖 outbound 做不到，只会追加同 tag 副本；单层目录、文件名字典序定合并序
- **`systemctl reload` = 改配置生效（轻）**；**`systemctl restart` = 网络切换恢复（重）**——两件事
- **proxy.address 为空 = 直连**：这是对"未配置代理也该正常访问"的防御性保证