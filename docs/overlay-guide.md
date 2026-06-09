# Overlay 制作指南

本文档总结如何通过 overlay 覆盖 nixpkgs 中的包，使用自定义的本地文件或指定版本。

## 适用场景

- 需要使用 nixpkgs 中没有的特定版本
- 需要使用本地预编译的二进制文件（如 `.deb`、`.tar.gz`）
- 需要修改包的编译参数或依赖

## 基本流程

### 1. 定义配置选项

在模块中定义 `src` 选项，让用户指定文件的 URL 和 hash：

```nix
options.desktop.vivaldi = {
  src = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        url = lib.mkOption { type = lib.types.str; };
        narHash = lib.mkOption { type = lib.types.str; };
      };
    });
    default = null;
    description = "安装包来源（指定 url 和 narHash）。非空时覆盖 nixpkgs 默认版本。";
  };
};
```

### 2. 使用 builtins.fetchTree 获取文件

```nix
config = let
  cfg = config.desktop.vivaldi;
  srcPath = if cfg.src != null
    then (builtins.fetchTree {
      type = "file";  # 或 "tarball"
      inherit (cfg.src) url narHash;
    }).outPath
    else null;
in { ... };
```

**要点**：
- `type = "file"` 用于单个文件（如 `.deb`、二进制）
- `type = "tarball"` 用于压缩包（如 `.tar.gz`）
- `narHash` 必须是 SRI 格式：`sha256-...`
- `.outPath` 返回的是字符串类型

### 3. 创建 overlay 覆盖包

```nix
nixpkgs.overlays = [
  (final: prev: let
    base = if srcPath != null
      then prev.<package>.overrideAttrs (old: {
        src = prev.runCommandLocal "<name>.deb" {} ''
          ln -s ${srcPath} $out
        '';
      })
      else prev.<package>;
  in {
    <package> = base.override {
      # 其他参数，如 commandLineArgs
    };
  })
];
```

## 关键要点

### ⚠️ src 必须是 derivation，不能是字符串

**错误示例**：
```nix
src = srcPath;  # ❌ srcPath 是字符串，会被当作 URL 处理
```

**正确做法**：用 `runCommandLocal` 包装成 derivation：
```nix
src = prev.runCommandLocal "name.deb" {} ''
  ln -s ${srcPath} $out
'';
```

### ⚠️ runCommand vs runCommandLocal

| 函数 | 构建位置 | 是否尝试远程 substitute | 推荐场景 |
|------|---------|------------------------|---------|
| `runCommand` | 可远程 | ✅ 会尝试，可能卡住 | 需要分布式构建 |
| `runCommandLocal` | 强制本地 | ❌ 不尝试 | **本地文件包装（推荐）** |

**问题**：`runCommand` 会尝试从 binary cache substitute，如果 derivation 名称匹配远程缓存中的包，会卡住等待网络。

**解决**：使用 `runCommandLocal` 强制本地构建，避免网络等待。

### ⚠️ symlink vs copy

- **symlink**（`ln -s`）：快，不占用额外空间，推荐用于大文件
- **copy**（`cp`）：慢，占用额外空间，但在某些特殊场景可能需要

### ⚠️ narHash 的获取

```bash
# 对本地文件计算 narHash
nix hash file --type sha256 /path/to/file

# 输出格式：sha256-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
```

### ⚠️ 文件 URL 格式

本地文件必须使用 `file://` 协议：
```nix
url = "file:///nix/store/xxxxx-package.deb";
```

## 完整示例

参考实现：
- `modules/desktop/units/vivaldi.nix` - 覆盖浏览器版本
- `modules/system/units/nushell.nix` - 覆盖 shell 版本

### vivaldi.nix（简化版）

```nix
{ pkgs, lib, config, ... }:

{
  options.desktop.vivaldi = {
    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = null;
    };
  };

  config = let
    cfg = config.desktop.vivaldi;
    srcPath = if cfg.src != null
      then (builtins.fetchTree {
        type = "file";
        inherit (cfg.src) url narHash;
      }).outPath
      else null;
  in {
    nixpkgs.overlays = [
      (final: prev: {
        vivaldi = if srcPath != null
          then prev.vivaldi.overrideAttrs (old: {
            src = prev.runCommandLocal "vivaldi.deb" {} ''
              ln -s ${srcPath} $out
            '';
          })
          else prev.vivaldi;
      })
    ];

    environment.systemPackages = with pkgs; [ vivaldi ];
  };
}
```

## 调试技巧

### 检查当前使用的版本

```bash
# 查看命令行版本
vivaldi --version

# 查看实际加载的二进制路径
which vivaldi
ls -la $(which vivaldi)
readlink -f $(which vivaldi)
```

**注意**：如果命令行版本正确但 GUI 版本不对，需要**重启程序**（Linux 进程加载的是旧的二进制到内存）。

### 检查 store 中的 derivation

```bash
# 列出所有相关 derivation
ls -la /nix/store/*vivaldi*.drv

# 查看 derivation 的依赖
nix-store -q --references /nix/store/xxx-vivaldi.drv
```

### 验证 overlay 是否生效

```bash
# 查看包的 src 属性
nix eval nixpkgs#vivaldi.src

# 查看 derivation 的构建参数
nix show-derivation $(nix eval --raw nixpkgs#vivaldi.drvPath)
```

## 常见错误

### 1. "querying xxx on https://..." 卡住

**原因**：使用了 `runCommand`，尝试从远程缓存 substitute。

**解决**：改用 `runCommandLocal`。

### 2. 版本没有更新

**原因**：
- 程序正在运行，使用的是内存中的旧版本
- overlay 没有正确应用

**解决**：
- 重启程序或注销重新登录
- 检查 overlay 语法和 `src` 包装是否正确

### 3. "src must be a path"

**原因**：`src` 被赋值为字符串，但需要 path 或 derivation。

**解决**：用 `runCommandLocal` 包装：
```nix
src = prev.runCommandLocal "name" {} ''
  ln -s ${srcPath} $out
'';
```

### 4. builtins.toPath 报错

**原因**：`builtins.toPath` 对绝对路径有限制。

**解决**：不要直接转换路径，而是用 `runCommandLocal` 创建 derivation。

## 总结

制作 overlay 的核心流程：
1. 定义配置选项（url + narHash）
2. 用 `builtins.fetchTree` 获取文件到 store
3. 用 `runCommandLocal` 包装成 derivation（**关键**）
4. 在 overlay 中用 `overrideAttrs` 覆盖 `src`

**黄金法则**：`src` 必须是 derivation，不能是字符串！
