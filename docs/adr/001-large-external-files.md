# ADR-001: 大体积外部文件的源管理策略

## 状态
已接受

## 背景
NixOS 配置中需要引入大体积外部文件（如 RIME 万象模型 ~200MB）。面临选择：

1. **绝对路径引用**：直接用 `/home/user/...` 路径
2. **Overlay 远程源 (URL/Hash)**：通过 `pkgs.fetchurl` 下载，或通过 `stdenv.mkDerivation` 重打包
3. **本地注入 (add-file)**：用户通过 `nix store add-file` 将本地文件加入 store

## 决策

### 默认行为：不启用 overlay
- 模块默认不引入大文件。
- 当未指定 `src` 时，使用模块默认行为。

### 覆盖方式 A：远程源 (URL + Hash)
- **适用场景**：
  - Nixpkgs 中缺失该文件，或版本严重滞后。
  - 文件有稳定的下载链接（URL）。
- **实现**：用户在 host 配置中构造 `fetchurl` derivation，传入 `outPath` 给模块。
- **扩展**：如果不仅是下载，还需要解压/重打包，可编写 `stdenv.mkDerivation` 脚本处理，再传入 `outPath`。
- **代价**：必须维护 Hash。上游文件更新后需同步更新，容易遗忘。

### 覆盖方式 B：本地注入 (add-file) — **推荐**
- **适用场景**：任意来源的文件（内网、邮件附件、本地副本）。
- **实现步骤**：
  1. 将文件放在任意位置（如 `~/Downloads/model.gram`）。
  2. `nix store add-file <文件>` 复制到 Nix Store 并返回路径。
  3. 配置中使用 `builtins.fetchTree` 包装该路径（纯评估模式要求）。
    ```nix
    rime.wanxiang.src = (builtins.fetchTree {
      type = "file";
      url = "file:///nix/store/xxxx-file.gram";
      narHash = "sha256-...";
    }).outPath;
    ```

- **核心优势：解耦配置与文件位置**
  - **现有的方式 `add-file` 就可以了，文件可以放在任意路径**。
  - **如果指定本地文件路径的话，要么改路径，要么改配置**，维护成本极高。
  - 通过 `add-file`，配置只依赖 Nix Store 中的不可变路径，源文件之后无论放在哪、甚至被删除，都不影响构建。
  - 无需 Git 追踪，大文件不入仓库。

### 禁止：绝对路径引用
- 不使用 `/home/user/...` 形式的绝对路径
- 理由：破坏 Nix purity，需 `--impure`，依赖本机状态

## 使用示例

### 方式 A：远程下载
```nix
rime.wanxiang.src = (pkgs.fetchurl {
  url = "https://.../model.gram";
  hash = "sha256-...";
}).outPath;
```

### 方式 B：本地注入
```bash
nix store add-file ~/Downloads/model.gram
# -> /nix/store/...-model.gram
```
```nix
# 必须配合 fetchTree 使用
rime.wanxiang.src = (builtins.fetchTree {
  type = "file";
  url = "file:///nix/store/...-model.gram";
  narHash = "sha256-...";
}).outPath;
```
