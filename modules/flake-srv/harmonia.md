# Harmonia 本地二进制缓存

引入 `modules/flake-srv/harmonia.nix` 即启用，无开关。

## 架构

- 使用 nixpkgs 预编译的 `harmonia` 二进制（无需源码编译）
- 自建 systemd service `harmonia`，直接调用 `harmonia-cache`
- 私钥内联在 `harmonia.nix` 中

## 密钥（固定，永久复用）

| 类型 | 值 |
|---|---|
| 私钥 | 内联于 `harmonia.nix` |
| 公钥 | `harmonia-local:bF/+RpECJWbbE8W7/hu1jWRlkQqu/+cXoVrWFENmqXY=` |

公钥已硬编码在 `modules/system/units/nix.nix` 的 `trusted-public-keys` 中。

## 服务

- 监听：`[::]:5100`
- 暴露：`/nix/store`
- 认证：无（仅局域网信任环境使用）

## 用法

目标机器的 `substituters` 加上：

```
http://<控制机IP>:5100
```

`trusted-public-keys` 已包含，无需额外配置。
