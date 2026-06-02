# ADR-002: Overlay 启用策略 — 按域而非按配置值

**日期**: 2026-06-01
**状态**: 已采纳
**上下文**: `libs/nixos-builder.nix` 第 27 行

### 问题

如何决定哪些节点应用 `modules/overlay/` 下的自定义 overlay（如 nushell 0.113.0）？

### 备选方案

| 方案 | 描述 | 缺点 |
|------|------|------|
| A. 按配置值 | 检查 role 模块中的 `programs.nushell.developMode` 或自定义 `nushell.developMode` 属性 | 需要 flake 提前导入 role 模块读取属性；`lib.mkForce` 返回 override 集合而非布尔值；引入模块求值顺序和参数传递复杂性 |
| B. 按文件名 | 检测 imports 是否包含 `workstation-base.nix` | 硬编码文件名，脆弱且不可扩展 |
| **C. 按域** | 通过 `nodeAttrs.domainName == "workstations"` 判断 | 需要新增域时修改判断条件 |

### 决策

采用 **方案 C**：在 `nixos-builder.nix` 中通过 `nodeAttrs.domainName == "workstations"` 决定是否启用 overlay。

```nix
nixpkgs.overlays = lib.optionals (nodeAttrs.domainName or null == "workstations")
  (map (name: import (overlayDir + "/${name}")) overlayFiles);
```

### 理由

1. **扩展合理** — workstations 是开发机，应用全部 overlay 符合直觉。**未来新增的 overlay（如自定义编译器、开发工具等）会自动生效，无需额外配置**。其他域（k8s/server/portable）用 nixpkgs 官方包，避免不必要的下载和构建
2. **改动最小** — 只改 builder 一行，不需要在 flake.nix 中传递额外配置，不需要修改 `builderKeys`
3. **职责清晰** — overlay 是 nixpkgs 打包层面的概念，应在构建器中统一决策。按域判断时：
   - **Builder 层**：决定「哪些机器需要自定义包」（一个域级判断）
   - **Role 层**：只声明「这个角色的功能需求」（如 workstation-base 声明需要开发工具、桌面环境）
   - 两层不互相渗透
   - 反之，如果在 builder 中读取 role 模块的 `programs.nushell.developMode`，role 模块就要知道「我设置这个值会影响 overlay 是否启用」，职责耦合
4. **无间接依赖** — 不需要在 flake 层提前导入 role 模块，避免了 `pkgs` 参数缺失、`lib.mkForce` 类型不匹配等问题

### 后果

- 新增需要 overlay 的域时，需在 builder 中添加对应的域名判断
- 如果将来某个非 workstations 域也需要 overlay，可改为白名单模式：`builtins.elem domainName [ "workstations" "other" ]`
