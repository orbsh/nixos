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
  3. 配置中直接传入 `{ url, narHash }` 属性集，模块内部自动处理 `fetchTree`。
    ```nix
    rime.wanxiang.src = {
      url = "file:///nix/store/xxxx-file.gram";
      narHash = "sha256-...";
    };
    ```
- **简化说明**：早期版本需要用户手动包装 `builtins.fetchTree`，现在模块内部封装了这一细节，用户只需提供 `url` 和 `narHash`。

- **核心优势：解耦配置与文件位置**
  - **现有的方式 `add-file` 就可以了，文件可以放在任意路径**。
  - **如果指定本地文件路径的话，要么改路径，要么改配置**，维护成本极高。
  - 通过 `add-file`，配置只依赖 Nix Store 中的不可变路径，源文件之后无论放在哪、甚至被删除，都不影响构建。
  - 无需 Git 追踪，大文件不入仓库。

### 禁止：绝对路径引用
- 不使用 `/home/user/...` 形式的绝对路径
- 理由：破坏 Nix purity，需 `--impure`，依赖本机状态

### 约束：无法省略 narHash
- **不可行方案**：只写 store 路径，让 Nix 自动计算 hash。
- **原因**：Nix 纯评估模式下，`fetchTree` 将 `file://` URL 视为未锁定输入，强制要求显式 `narHash`。即使文件已在 store 中（路径 hash 已含内容校验），也无法省略。
- **路径 hash ≠ narHash**：路径中的 hash（如 `h1dwvavq0qx...`）是 base32 编码的 SHA-256 截断；`narHash` 是 base64 编码的完整 SHA-256。两者同源但编码不同，无法从路径字符串精确还原。
- **正确做法**：`nix hash path /nix/store/xxx` 查看 narHash，然后填入 `fetchTree`。

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
# 直接传入 url 和 flat hash，模块内部用 pkgs.fetchurl（FOD）
rime.wanxiang.src = {
  url = "file:///nix/store/...-model.gram";
  hash = "sha256-...";   # nix hash file --type sha256 --sri
};
```

> **注意**：早期版本需要手动包装 `(builtins.fetchTree { ... }).outPath`，现在模块已封装此细节。

## Update（2026-10-28）：取物从 eval 期改到构建期

原方案用 `builtins.fetchTree { type = "file"; narHash; }`，取物发生在 eval 期。它的“命中”依赖**本机** `~/.cache/nix/fetcher-cache` 的 URL 记录，不在 store 里——store 里明明有那个路径，换台机器 eval 仍会重新下载。镜像地址是 `http://box.d`（只有工作站能解析）时，任何在服务器上 eval 的路径都必然失败，而且把产物推过去也无效。

现统一改为 `pkgs.fetchurl { url; hash; }`：固定输出 derivation 的判定是 `isValidPath(output)`，产物推过去就跳过下载，可作为构建输入随闭包分发。代价是 hash 从 narHash（`nix hash path`）改用 flat sha256（`nix hash file --sri`），`scripts/upstream.yml` 的 mirror 条目因此统一为 `hash: flat`。

唯一例外：`modules/desktop/units/rime-wubi.nix` 取的是 git 仓库（`fetchTree type = "git"`），没有 rev 就无法表达成 FOD，继续保留 eval 期取物。
