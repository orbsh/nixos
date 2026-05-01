# 项目级环境配置

在 Nix 中，你可以通过 `flake.nix` 的 `devShells` 或 `shell.nix` 为每个项目创建独立的环境，类似于 Python 的 `venv`，但支持任意语言和工具。

## 方式 1：使用 `nix develop`（推荐，Flake 风格）

在项目的根目录创建 `flake.nix`，定义 `devShells`：

```nix
# my-project/flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }: {
    devShells.x86_64-linux.default =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
      in pkgs.mkShell {
        packages = with pkgs; [
          python312
          poetry
          nodejs_20
        ];
        shellHook = ''
          echo "Welcome to my-project environment!"
        '';
      };
  };
}
```

然后进入项目目录并激活环境：
```bash
cd my-project
nix develop   # 进入环境，可使用项目所需的 python、poetry、node 等
exit          # 退出后环境失效，不影响系统
```

## 方式 2：使用 `shell.nix`（传统方式）

在项目根目录创建 `shell.nix`：

```nix
# my-project/shell.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    python312
    uv
    rustup
  ];
}
```

激活环境：
```bash
cd my-project
nix-shell   # 或使用 nix develop（如果启用 flakes 兼容）
```

## 方式 3：使用 direnv 自动切换（推荐）

安装 `direnv` 后，在项目目录创建 `.envrc`：
```bash
# my-project/.envrc
use flake
```

然后允许 direnv：
```bash
direnv allow
```

每次 `cd` 进入该项目目录时，环境会自动激活；离开时自动恢复。无需手动输入 `nix develop`。

### 💡 与 Python venv 的对比

| 特性 | Python venv | Nix devShell |
|------|-------------|--------------|
| 隔离级别 | 仅 Python 包 | 系统级（任意语言、工具、库） |
| 依赖管理 | 手动 pip install | 声明式（nix 文件记录版本） |
| 复现性 | 依赖网络/OS | 完全锁定（flake.lock） |
| 跨平台 | 需分别处理 | 同一配置多架构支持 |

> 建议：对于任何语言的项目，都可以使用 Nix devShell 作为环境基础，再配合语言专属工具（如 `uv venv`、`cargo`、`bun`）管理运行时依赖。