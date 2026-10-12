# legacy —— 未启用模块的存放区

这里放**当前没有被任何 host 引入**的模块：已废弃/被替代的、或暂时禁用留待将来启用的。
放进来等于退出活跃树：`legacy/` 不被 flake、hosts、profiles 引用，不参与求值。

## 约定

- 目录结构镜像 `modules/` 下的原相对路径（如原 `modules/dev/units/zed.nix` → `modules/legacy/dev/units/zed.nix`），便于对号入座。
- 文件内部的相对引用已按**新位置**算好——`legacy/` 内互相 import 能正常解析；指向仍在活跃树的文件的引用已相应加了一层 `../`。
- 各聚合器里原本指向这些文件的注释行已改为指向 `legacy/` 路径（如 `modules/dev/fullstack.nix` 的 `# ../legacy/dev/units/zed.nix`），看注释就知道东西还在哪。

## 启用方式

1. 把文件移回原位：`modules/legacy/<相对路径>` → `modules/<相对路径>`。
2. 在对应聚合器里取消注释（注释里的路径是 legacy 位置，移回后要改回原位路径）。
3. 搬回后把文件内相对引用的 `../` 层数减 1（或直接从 git 历史取搬入 legacy 前的版本）。
4. 该模块若有 host 实例文件（如 `hosts/workstations/surreal.nix`），把它加进对应节点的 `imports`。

## 清单

| 文件（legacy 内路径） | 原位置 | 状态 | 说明 |
|---|---|---|---|
| `desktop/units/de-session/hyprland.nix` | de-session | 禁用 | de-session 的 imports 中已注释；现行会话为 cosmic / niri |
| `desktop/units/de-session/quickshell.nix` | de-session | 禁用 | 同上（Hyprland 侧组件） |
| `desktop/units/de-session/vicinae.nix` | de-session | 禁用（2026-08-27） | 改回以 walker 为主启动器 |
| `desktop/units/de-session/eww.nix` | de-session | 已废弃（2026-08） | cosmic 用自带 shell，监视挂件迁往 Noctalia |
| `desktop/units/feishu.nix` | desktop/units | 未引入 | apps-im 中已注释 |
| `desktop/units/nyxt.nix` | desktop/units | 无引用 | 从未接入任何聚合器 |
| `desktop/units/zellij.nix` | desktop/units | 未引入 | 终端复用改用 herdr |
| `dev/units/codex.nix` | dev/units | 无引用 | 未被任何 flavor 引入 |
| `dev/units/emacs.nix` | dev/units | 默认禁用 | 需在 host 定义中显式引入 |
| `dev/units/mysql-server.nix` | dev/units | 未引入 | 各 flavor 中已注释 |
| `dev/units/zed.nix` | dev/units | 已禁用 | 编辑器改用 neovim / helix |
| `dev/units/surrealdb-server.nix` | dev/units | 已取消 | 服务端不再使用；`hosts/workstations/surreal.nix` 是它的孤儿实例文件 |
| `k8s/istio-gateway.nix` | k8s | 未引入 | 与 envoy-gateway 互斥，当前用后者 |
| `services/headscale.nix` | services | 无引用 | 控制面在 K8s 侧部署，本机仅作 Tailscale 客户端 |
| `services/ladder.nix` | services | 已被替代 | ADR-022：singbox 取代 mihomo/podman 容器方案 |
| `services/podman/aria2.nix` | services/podman | 无引用 | 从未接入 |
| `system/units/home-kakoune.nix` | system/units | 未引入 | core 中已注释 |
| `system/units/lsp-bridge.nix` | system/units | 已停用 | lsp-bridge 是 emacs 侧 LSP，emacs 已放弃 |

## 不在本目录的

`dev/` 下的 `backend.nix` / `data-science.nix` / `infrastructure.nix` 与 `dev/units/postgresql-server.nix` 是**占位**（骨架保留、暂未接入任何 profile），仍留在 `modules/` 活跃树内，不在 legacy。
