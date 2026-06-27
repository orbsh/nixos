# ADR-017: 全局可变配置归属 flake.nix

**日期**: 2026-06-27
**状态**: 已采纳

### 问题

substituters、公共 DNS 等全局配置应该放在哪里？它们可能因网络状况频繁调整（如临时禁用官方镜像），放在 modules/ 里不好找。

### 决策

按配置的变更频率和作用域分三层：

| 位置 | 语义 | 变更频率 | 示例 |
|------|------|----------|------|
| `flake.nix` `commonArgs` | 全局，可能调整 | 低（但确实会改） | substituters、公共 DNS |
| `hosts/<host>/` | 非全局，可能调整 | 中 | 硬件特有配置、节点角色 |
| `modules/` | 不可变逻辑 | 高（仍在演进） | 系统模块、服务配置 |

### 实现

`flake.nix` 的 `commonArgs` 定义全局变量（`nixSubstituters`、`publicDnsServers`），模块通过函数参数消费。修改 substituters 只需改 `flake.nix` 一处。

### 理由

1. **可发现性** — `flake.nix` 是入口文件，打开就能看到所有全局配置
2. **单一配置源** — 避免 substituters 分散在多个模块中（`nix.nix` + `harmonia-cache.nix` 各管一段）
3. **概念清晰** — flake.nix 是「工厂」，定义全局变量；modules 是「产品」，消费变量
4. **harmonia-cache.nix 追加不受影响** — NixOS 模块系统自动合并 `nix.settings`，本地缓存追加到列表末尾

### 后果

- substituters 和公共 DNS 统一在 `flake.nix` 的 `commonArgs` 中定义
- `modules/system/units/nix.nix` 通过函数参数 `nixSubstituters` 消费
- harmonia-cache.nix 通过 NixOS 模块系统自动追加本地缓存