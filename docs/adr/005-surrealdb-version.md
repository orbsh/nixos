# ADR-005: SurrealDB 版本管理 — 模块级局部 Overlay

**日期**: 2026-06-02
**状态**: 已采纳

### 问题

SurrealDB 需要固定到 3.0.5 版本，如何选择版本覆盖的方式？

### 备选方案

| 方案 | 描述 | 影响范围 |
|------|------|------|
| A. `package = pkgs.surrealdb.overrideAttrs ...` | 在 `services.surrealdb.package` 参数处直接替换 | 仅该服务实例，同 host 其他 `pkgs.surrealdb` 仍为原版 |
| B. 全局 overlay（`modules/overlay/surrealdb.nix`） | 在 `modules/overlay/` 中定义，通过 builder 注入 | **所有** workstations 节点，不论是否引入该模块 |
| **C. 模块级 overlay**（`nixpkgs.overlays = [...]`） | 在 `surrealdb-server.nix` 内部注入 | **引入该模块的 host** 内所有 `pkgs.surrealdb` |

### 决策

采用 **方案 C**：在模块内部通过 `nixpkgs.overlays` 注入 overlay。

```nix
{ pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      surrealdb = prev.surrealdb.overrideAttrs (old: { ... });
    })
  ];

  services.surrealdb = { enable = true; };
}
```

### 理由

1. **引入即启用** — 模块职责内聚：声明启用服务 + 统一版本，一次 import 搞定
2. **版本安全** — 防止同 host 内意外混用不同版本的 surrealdb（方案 A 存在此风险）
3. **不影响其他 host** — 仅引入该模块的 host 生效，不污染全局 overlay（方案 B 的缺点）
4. **符合「引入既启用」的设计哲学** — 与项目中其他模块的行为模式一致

### 后果

- 引入 `surrealdb-server.nix` 的 host，其所有 `pkgs.surrealdb` 引用都指向 3.0.5
- 其他未引入该模块的 host 不受影响，仍使用 nixpkgs 原版
