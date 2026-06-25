# ADR-016: lsp-bridge 模块归属与 Python 依赖模式

## 状态
已采纳

## 背景
lsp-bridge 是一个远程代码智能工具，通过 SSH 在服务端启动 Python 后端，与本地 Emacs 通信。它需要一组 Python 包（epc、orjson、sexpdata 等）作为运行时依赖。

NixOS 模块已有 `dev/units/python.nix`，包含开发用 Python 包（uv、fastapi、pydantic 等）。lsp-bridge 的 Python 依赖与开发包无关——它是远程管理工具，不是开发依赖。

## 决策
1. **lsp-bridge.nix 放在 `modules/system/units/`**，与 `home-base.nix`、`home-git.nix` 同级，通过 `modules/system/home.nix` 统一引入所有 host。
2. **lsp-bridge.nix 自带 `python3.withPackages`**，不合并到 `dev/units/python.nix`。
3. 模块按**功能**划分，不按**实现语言**划分。

## 理由
- **功能归属**：lsp-bridge 的核心价值是远程开发/管理，与 Python 开发生态无关。把它放进 python.nix 等于说"lsp-bridge 是 Python 工具"，但它本质是"远程桥梁"。
- **独立演进**：lsp-bridge 的 Python 依赖（epc、sexpdata 等）与开发包（fastapi、pydantic 等）没有交集。合并会导致一个模块承担两种职责，修改一方容易波及另一方。
- **全 host 覆盖**：通过追溯导入链确认所有 host 都有 Python（workstation → fullstack → python.nix；k8s → server → python.nix；portable → rescue → python.nix）。lsp-bridge 作为系统级工具，从 home.nix 引入是合理的。
- **NixOS 多 Python 环境**：多个 `python3.withPackages` 可以共存于同一系统，各自独立编译，不冲突。PATH 顺序由 NixOS 模块加载顺序决定。

## 导入链
```
presets/workstation.nix → system/home.nix → system/units/lsp-bridge.nix
presets/server.nix      → system/home.nix → system/units/lsp-bridge.nix
presets/portable.nix    → system/home.nix → system/units/lsp-bridge.nix
```

## 相关
- `dev/units/python.nix` — 开发用 Python（功能不同，独立维护）
- `modules/system/home.nix` — 所有 host 的 HM 聚合入口
- ADR-011: 模块组织与 HM 集成

## 补充：客户端 vs 服务端 Python 环境的双重声明

`dev/units/emacs.nix` 声明了 `emacsWithPythonDeps`（9 个 Python 包），`system/units/lsp-bridge.nix` 声明了 `lspBridgePython`（同样的 9 个包）。两者表面上重复，但设计上独立：

- **emacs.nix 的 `emacsWithPythonDeps`**：本地 Emacs 客户端需要，lsp-bridge 的 Elisp 前端在本地调用 Python 进程时使用。
- **lsp-bridge.nix 的 `lspBridgePython`**：远程服务端需要，lsp-bridge 的 Python 后端在服务端运行时使用。

当前所有 host 恰好同时有两者（workstation 通过 fullstack → emacs.nix，所有 host 通过 system/home.nix → lsp-bridge.nix）。但这是偶然重叠，不是必然耦合：

- 纯服务端（如 k8s 节点）只有 `lspBridgePython`，没有 `emacsWithPythonDeps`（不需要本地 Emacs）
- 未来如果客户端只通过 SSH 连远程开发，本地可能不需要 `emacsWithPythonDeps`

**原则：两个 Python 环境按职责独立声明，不因为当前恰好相同而合并。**
