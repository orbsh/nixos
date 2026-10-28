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
        hash = lib.mkOption { type = lib.types.str; };
      };
    });
    default = null;
    description = "安装包来源（指定 url 和 flat hash）。非空时覆盖 nixpkgs 默认版本。";
  };
};
```

### 2. 用 pkgs.fetchurl 取文件（固定输出 derivation）

```nix
config = let
  cfg = config.desktop.vivaldi;
  srcPath = if cfg.src != null
    then pkgs.fetchurl { inherit (cfg.src) url hash; }
    else null;
in { ... };
```

**要点**：
- 一律用 `pkgs.fetchurl`（压缩包也一样；stdenv 会自动解包），不要用 `builtins.fetchTree`
- `hash` 是 **flat sha256**（SRI 格式 `sha256-...`），不是 narHash
- `srcPath` 现在本身就是 derivation，可以直接当 `src` 用，不需要 `.outPath`

为什么不用 `builtins.fetchTree`：

| | `builtins.fetchTree` | `pkgs.fetchurl`（FOD） |
|---|---|---|
| 取物时机 | eval 期 | 构建期 |
| 是否需要重新下载 | 由本机 `~/.cache/nix/fetcher-cache` 的 URL 记录决定 | 由 store 里有没有该产物决定 |
| 产物推给别的机器 | 推了也没用（缓存不在 store 里），目标机照样联网 | 推过去就跳过下载（`isValidPath(output)`） |
| 跨机器部署 | 目标机必须能访问那个 URL | 可以先在工作站取好再推 |

镜像在 box.d（只有工作站能解析）这类场景必须走 FOD，否则服务器或节点 eval 时必然卡在取物上。

### 3. 创建 overlay 覆盖包

```nix
nixpkgs.overlays = [
  (final: prev: let
    base = if srcPath != null
      then prev.<package>.overrideAttrs (old: {
        src = srcPath;  # 已经是 derivation，直接给
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

```nix
src = "/nix/store/xxx";   # ❌ 字符串会被当成 URL 处理
src = pkgs.fetchurl { url = ...; hash = ...; };  # ✅
```

`builtins.fetchTree {...}.outPath` 之所以要包一层 `runCommandLocal`，就是因为它返回的是字符串；换成 `fetchurl` 之后这一层包装可以去掉。

### ⚠️ 解包行为与 sourceRoot

`pkgs.fetchurl` 拿到的是压缩包本体，stdenv 会走 `unpackPhase`。压缩包**没有顶层目录**时（如 rbw 的 tarball 根下直接是 `rbw`/`completion/`），stdenv 的 sourceRoot 推断会选错目录，需要显式钉住：

```nix
src = pkgs.fetchurl { url = ...; hash = ...; };
sourceRoot = ".";
```

需要自己控制解包时用 `dontUnpack = true` + 在 `installPhase` 里 `tar xzf $src`（jcode、numa 是这种形态）。

### ⚠️ runCommandLocal 现在只用于改名场景

`src` 是 tarball 或 `.deb` 时，store 路径名已经是 `xxx.tar.gz` / `xxx.deb`，上游的 `unpackCmd` 认得，不需要包装。只有当上游要求特定文件名、而 hash 来源路径名不匹配时才用：

```nix
src = prev.runCommandLocal "vivaldi.deb" {} ''
  ln -s ${srcPath} $out
'';
```

### ⚠️ symlink vs copy

- **symlink**（`ln -s`）：快，不占额外空间，推荐用于大文件
- **copy**（`cp`）：慢，占额外空间，特殊场景才需要

### ⚠️ flat hash 的获取

```bash
# 单个文件（FOD 用这个）
nix hash file --type sha256 --sri /path/to/file
# 或者直接看 URL 的规范值
nix store prefetch-file --json http://box.d/nixos/<file>
# → {"hash":"sha256-...","storePath":"..."}
```

narHash（`nix hash path`，NAR 哈希）只在继续用 `builtins.fetchTree` 的少数条目上需要（当前仅 `modules/desktop/units/rime-wubi.nix` 的 git 源，git 取物没有 rev 就没法做 FOD）。

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
          hash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = null;
    };
  };

  config = let
    cfg = config.desktop.vivaldi;
    srcPath = if cfg.src != null
      then pkgs.fetchurl { inherit (cfg.src) url hash; }
      else null;
  in {
    nixpkgs.overlays = [
      (final: prev: {
        vivaldi = if srcPath != null
          then prev.vivaldi.overrideAttrs (old: { src = srcPath; })
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
1. 定义配置选项（url + flat hash）
2. 用 `builtins.fetchTree` 获取文件到 store
3. 用 `runCommandLocal` 包装成 derivation（**关键**）
4. 在 overlay 中用 `overrideAttrs` 覆盖 `src`

**黄金法则**：`src` 必须是 derivation，不能是字符串！
