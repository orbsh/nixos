# sing-box 可复用代理组件（替换 mihomo/ladder）方案

> **状态**: 已实现（2026-08-25），决策记录见 ADR-022
> **创建时间**: 2026-08-24
> **目标**: 用轻量 sing-box 组件替换 mihomo/ladder，配置声明式进 NixOS，全 hosts 可复用，工作站走代理、服务器全直连占位，并根治"网络切换后需手动重启"的痛点

---

## 一、背景与痛点

现有代理架构（workstation/portable）：

- `modules/services/ladder.nix` → mihomo（podman 容器，端口 7890/7891/9090）
- mihomo 配置在 **NixOS 配置系统外**：`${dataDir}/ladder/mihomo/config.yaml`（非 store symlink，可手改）——即"配置在外面，比较重"
- 需替换的原因：
  1. mihomo 重、配置在配置系统外、只有 workstation 有（服务端部署麻烦）
  2. 曾用 sing-box 时有一个痛点：**切换网络后不自动重连，经常需手动重启**

---

## 二、已核实事实（源码/CLI 实证,勿凭印象）

### 配置格式
- **只支持 JSON / JSONC（带注释/尾逗号），不支持 YAML/TOML**（实测 1.13.19 + 源码级确认）
  - sing 库 `common/json/` 只有 contextjson+badjson，**无 yaml/toml 解析器**
  - `go.mod` 无 yaml/toml 依赖；nixpkgs `tags` 无 yaml/toml 开关
  - `sing-box check -c config.toml` 报 "invalid character 'l'"——实测否定 TOML

### 配置合并机制（源码实证）
加载 = 深度合并：
- `-c` 收集指定文件 + `-C` 收集目录下**每个 .json 非目录文件** → 按路径字典序排序 → `MergeJSON` 深并
- **数组 → 追加串联**；**对象 → 递归深并**；标量同键 → 后者覆盖
- **`-C` 只认 `.json`，不递归子目录** → 单层目录，rule_set 数据文件平铺同目录、靠 path 引用

### 热更新
- `kill -HUP` / `systemctl reload singbox.service` 重扫 `-C` 目录重新加载；新增/删/改 `.json` 即生效，无需 rebuild
- **⚠️ HUP 前会 `check()` 校验**：新文件有语法错误则 reload 失败（旧实例已 Close → 空窗）→ 组件 ExecReload 用"先 check 后 reload"两行守卫（systemd 逐行，行1 失败则不执行行2，旧进程继续）

---

## 三、最终架构（ADR-022）

### 组件：`modules/services/singbox.nix`（系统级 service）

- **引入即起效，无 `enable` 选项**——对齐仓库 service 组件范式
- 单层配置目录 `~/.config/singbox/`，全用 `-C` 自动深度合并 `*.json`：
  - `config.json`（log/inbounds/outbounds[direct 兜底]/route 框架，final=direct）
  - `outbounds.json`（出口扩展点，数组留空+注释）
  - `rules.json`（rule_set 声明，type local + path 同目录引用）
- 默认 **final=direct 全直连兜底**（无规则全直连）；要代理出口手改 outbounds.json 追加 + rules.json 引用
- `ExecReload = [ sing-box check -C <dir>; kill -HUP $MAINPID ]` 守卫
- 网络切换自动重连（双层）：
  - **层1 NM dispatcher**：网络 up/down/vpn-up/vpn-down → restart
  - **层2 健康检查 timer**：每 2 分钟 curl 探活，连续 3 次失败 → restart
- 各 profile 分别引入：server/workstation/portable/qemu 全 ✓，`wantedBy=multi-user.target`

### 共享代理地址：`config.proxy.address`（core.nix 定义）

- 类型 `nullOr str`，默认 `null`（= 不走代理，直连）
- singbox 引入时自动赋：`proxy.address = mkDefault "http://127.0.0.1:<listenPort>"`
- nix-daemon、vicinae 从该变量派生 http_proxy，**为空时直连**
- 完整 URI → 可指向任意代理服务（`socks5://host:port` 等）
- 定义于 core.nix（全 hosts 公共基座）→ 独立于 singbox 存在，换代理只改这一处

### noProxy 白名单（flake.nix）

- 并入 `nixSubstituters = { substituters, noProxy, trusted-public-keys }`（与 substituters 同层）
- nix.nix 消费：`no_proxy = lib.concatStringsSep "," nixSubstituters.noProxy`
- 镜像（ustc/tuna/sjtu）→ noProxy 直连；官网 cache.nixos.org → 走代理

### 机器映射

| 机器 | singbox | proxy.address | nix-daemon |
|------|---------|---------------|------------|
| workstation | ✓（6789 测试端口） | `http://127.0.0.1:6789` | 跟随 |
| server | ✓ 全直连占位（7890） | `http://127.0.0.1:7890` | 跟随 |
| qemu | ✓ 全直连占位（7890） | `http://127.0.0.1:7890` | 跟随 |
| 不引 singbox | — | `null`（直连） | 不设 http_proxy |

**已删**: `hosts/workstations/nix-proxy.nix`（原显式设 7890，现由共享变量默认覆盖，冗余）

---

## 四、测试流程（待办）

1. workstation 以 **6789** 测试端口验证 sing-box（避免与 mihomo 7890 冲突）
2. 验证通过后：workstation `listenPort` 改回默认 **7890**
3. 停 mihomo ladder（`modules/services/ladder.nix` 保留作对照，确认切换后再清理）

---

## 五、关键约束（别踩）

- sing-box **只支持 JSON/JSONC**；`-C` 目录只认 `.json`、不递归子目录
- **数组追加非覆盖**：覆盖 outbound 做不到，只会追加同 tag 副本；单层目录、文件名字典序定合并序
- **`systemctl reload` = 改配置生效（轻）**；**`systemctl restart` = 网络切换恢复（重）**——两件事
- **proxy.address 为空 = 直连**：对"未配置代理也该正常访问"的防御性保证
- 上游出口若用明文不加密 SOCKS5/HTTP 转发，不可信链路有中间人风险（需权衡）