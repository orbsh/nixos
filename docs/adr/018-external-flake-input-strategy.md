# ADR-018: 外部 flake input 策略

**日期**: 2026-07-29
**状态**: 已采纳

### 问题

项目依赖两类外部来源：

1. **自定义配置仓库**（`my-nushell-config`、`my-emacs-config`、`my-nvim-config`）— 个人定制，其他用户可替换为自己的仓库
2. **社区 NixOS 模块**（如 `nixos-cosmic`）— 第三方维护，可能随上游稳定后移除

是否都应作为 `flake.nix` 的 input？

### 决策

区分对待：

| 类型 | 放置位置 | 理由 |
|------|----------|------|
| 自定义配置 (`my-*`) | `flake.nix` input | 个人定制，其他用户可替换为自己的仓库；放在入口一眼可见，方便替换 |
| 社区模块（可能废弃） | 模块内 `builtins.fetchGit` | 自包含，不导入时不拉取；废弃后改开关即可，无需动 `flake.nix` |

### 实现

- `my-*` input 留在 `flake.nix`，通过 `commonArgs` 注入模块
- 社区模块在对应 unit 文件内自包含 fetch（`builtins.fetchGit` / `builtins.fetchTarball`），不导入即不拉取
- 曾用 `let useGitOverlay = true/false` 开关控制 nixos-cosmic 是否启用；上游稳定进 nixpkgs 后，开关与 fetch 逻辑随案例一并删除
- 上游 hash 问题时通过 `nixpkgs.overlays` 在同文件内修正

### 理由

1. **最小侵入** — `flake.nix` 只保留长期使用的 input；临时依赖不污染入口文件
2. **自包含** — 社区模块的 fetch 逻辑、hash 修正、开关与使用点同文件
3. **可发现性** — `my-*` input 集中在 `flake.nix` 前部，其他用户 fork 后一眼可见替换点
4. **flake.lock 卫生** — 移除临时 input 后 `flake.lock` 不再包含无关条目

### 后果

- `flake.nix` 不再有 `nixos-cosmic` input
- `modules/desktop/units/de-session/cosmic.nix` 曾以 `useGitOverlay` 开关 + `builtins.fetchGit` 自包含 Git 版 COSMIC；COSMIC 稳定进 nixpkgs（现为 1.9.x）后开关置 `false`，随后（2026-10）开关、`builtins.fetchGit` 与上游 hash 修正一并删除，模块只留 pipewire / portal / pop-launcher 等实际配置
- 第二类（社区/临时依赖在模块内自包含 fetch）目前没有在用实例：唯一候选 `modules/legacy/dev/units/surrealdb-server.nix` 已随 SurrealDB 服务端取消而停用（原 `modules/dev/units/surrealdb-server.nix`，2026-10 移入 legacy）
- 模块内 fetch 不受 `flake.lock` 锁定，需显式钉 `url` / `rev` / `sha256` 保证可复现
