# ADR-015: 编辑器 Home Manager 配置分发策略

**日期**: 2026-06-24
**状态**: 已采纳
**前置**: ADR-011（模块组织与 HM 集成策略）

### 问题

1. 编辑器（Neovim、Emacs）配置需要在不同 host 上可用，但各场景的部署方式不同（本地开发 vs store 只读）
2. HM 的 `programs.neovim` 模块在 nixpkgs 25.11 中因 `neovimUtils.makeVimPackageInfo` 移除而存在兼容问题，且会生成默认 `init.lua` 与自定义配置冲突
3. 服务器节点不需要开发模式的工具链（lua-language-server、clangd 等），但需要编辑器和插件同步
4. 多个编辑器同时设置 `EDITOR` 环境变量会冲突

### 决策

**Neovim** 统一通过 `system/home.nix` 分发到所有 preset（workstation/server/portable/qemu），通过 `developMode` 标志区分部署行为。

**Emacs** 仅在 workstation preset 中引入（通过 `dev/units/home-emacs.nix`），服务器/K8s 节点不引入。

#### 1. Neovim 分发链路

```
modules/presets/{workstation,server,portable,qemu}.nix
    └── imports: ../system/home.nix
            └── imports: ./units/home-nvim.nix
```

##### developMode 差异化

| developMode | 行为 | 适用 host |
|-------------|------|-----------|
| `true` | `~/.config/nvim` symlink 到本地目录；安装 lua-language-server | workstation |
| `false` | `~/.config/nvim` 指向 store 中的 flake input；activation script 自动 `Lazy! sync` | server, portable, qemu |

##### 不使用 HM programs.neovim 模块

`home-nvim.nix` 始终通过 `home.packages` 直接安装 nvim，而非使用 HM 的 `programs.neovim`：

```nix
home.packages = with pkgs; [
  neovim ripgrep fd tree-sitter
] ++ lib.optionals developMode [
  lua-language-server
];
```

**原因**：
- `programs.neovim` 会生成默认 init.lua，与自定义配置冲突
- 直接装包更透明，避免 HM 隐式行为
- 与 `xdg.configFile."nvim"` 部署方式配合更好

#### 2. Emacs 分发链路

```
modules/presets/workstation.nix
    └── imports: ../dev/units/home-emacs.nix
```

Emacs 仅在 workstation 中引入，不通过 `system/home.nix` 统一分发。

**原因**：
- Emacs 体积较大（closure 925MB），K8s/服务器节点不需要
- 服务器上不存在 `~/Configuration/emacs` 目录，无条件部署会导致 activation 失败
- 避免与 nvim 的 `EDITOR` 设置冲突

##### developMode 差异化

| developMode | 行为 | 适用 host |
|-------------|------|-----------|
| `true` | `~/.config/emacs` symlink 到本地目录；安装 clangd、python3、typescript-language-server | workstation |
| `false` | `~/.config/emacs` 仅当本地路径存在时部署；activation script 检查目录后决定是否同步 | server, portable, qemu |

##### 不设置 EDITOR

`home-emacs.nix` 不设置 `EDITOR` / `VISUAL` 环境变量，避免与 nvim 冲突。

**原因**：
- `home-nvim.nix` 先导入，已设置 `EDITOR=nvim`
- 如果 emacs 需要接管编辑器，应在节点级别覆盖，而非在模块中硬编码

#### 3. 编辑器包对比

| 包 | 条件 | 引入位置 | 用途 |
|----|------|---------|------|
| `neovim` | 始终 | system/home.nix | 编辑器本体 |
| `ripgrep` | 始终 | system/home.nix | 内容搜索 |
| `fd` | 始终 | system/home.nix | 文件发现 |
| `tree-sitter` | 始终 | system/home.nix | 语法解析 |
| `lua-language-server` | 仅 developMode | system/home.nix | Lua LSP（nvim 专用） |
| `emacs-nox` | 仅 workstation | dev/units/home-emacs.nix | Emacs 编辑器 |
| `clangd` | 仅 developMode | dev/units/home-emacs.nix | C/C++ LSP |
| `python3` | 仅 developMode | dev/units/home-emacs.nix | Python |
| `typescript-language-server` | 仅 developMode | dev/units/home-emacs.nix | TypeScript LSP |

### 架构总览

```
                    ┌─ workstation ─── developMode=true
system/home.nix ────┤   ├─ nvim:  symlink 本地目录 + Lazy! sync
  └─ home-nvim.nix  │   └─ emacs: symlink 本地目录（via dev/units/home-emacs.nix）
                    │
                    ├─ server ─────── developMode=false
                    │   └─ nvim:  store flake input + Lazy! sync
                    │       └─ mkForce disable programs.neovim
                    │
                    ├─ portable ───── developMode=false
                    │   └─ nvim:  store flake input + Lazy! sync
                    │
                    └─ qemu ───────── developMode=false
                        └─ nvim:  store flake input + Lazy! sync
```

### Host 完整映射

| Preset | Hosts | developMode | nvim | emacs |
|--------|-------|-------------|------|-------|
| workstation.nix | orbit, team-alice, team-bob | `true` | symlink 本地目录 | symlink 本地目录 |
| server.nix | server, k8s-*/dxserver | `false` | store flake input + mkForce disable | 不引入 |
| portable.nix | portable | `false` | store flake input | 不引入 |
| qemu.nix | qemu | `false` | store flake input | 不引入 |

### 理由

1. **Neovim 统一** — 所有 host 共享同一个编辑器模块，保证环境一致性
2. **Emacs 按需** — 仅 workstation 引入，避免服务器/K8s 节点的体积开销
3. **差异化部署** — `developMode` 一个标志控制开发/生产两种模式
4. **避免冲突** — server.nix 禁用 HM neovim 模块；emacs 不设置 EDITOR
5. **K8s 节点可用** — 服务器节点仍有 nvim，方便紧急编辑

### 后果

- 所有 host 都会安装 nvim 包（含 K8s 节点），增加少量 store 占用
- Emacs 仅 workstation 有配置，服务器上不可用
- `server.nix` 需要 `mkForce false` 来覆盖 HM neovim 模块，属于 workaround
- `EDITOR` 统一由 `home-nvim.nix` 设置为 `nvim`，emacs 不接管
