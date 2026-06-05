# NixOS Binary Cache

本项目使用 [Harmonia](https://github.com/nix-community/harmonia) 作为局域网二进制缓存服务，避免在各节点重复构建。

## 架构

- 使用 nixpkgs 预编译的 `harmonia` 二进制（无需源码编译）
- 自建 systemd service `harmonia`，直接调用 `harmonia-cache`
- 引入 `modules/flake-srv/harmonia.nix` 即启用，无开关

## 密钥（固定，永久复用）

| 类型 | 值 |
|---|---|
| 私钥 | 内联于 `harmonia.nix` |
| 公钥 | `harmonia-local:bF/+RpECJWbbE8W7/hu1jWRlkQqu/+cXoVrWFENmqXY=` |

公钥已硬编码在 `modules/system/units/nix.nix` 的 `trusted-public-keys` 中。

## 服务配置

- 监听：`[::]:5100`
- 暴露：`/nix/store`
- 认证：无（仅局域网信任环境使用）

## 客户端配置

目标机器的 `substituters` 加上：

```
http://<控制机IP>:5100
```

`trusted-public-keys` 已包含，无需额外配置。

## S3 / MinIO 缓存（可选）

适用于持久化存储或跨网络访问（如集群级缓存）。

### 推送到 S3

需要 `awscli` 或有效的 AWS 环境变量（`AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`、`AWS_DEFAULT_REGION`）。

```bash
# 推送指定路径
nix copy --to 's3://bucket-name?endpoint=https://s3.your-domain.com' /nix/store/hash-foo

# 推送当前系统闭包
nix copy --to 's3://nix-cache?endpoint=https://registry.s' $(nixos-rebuild build --flake .#myhost)
```

### 客户端配置

```nix
{
  nix.settings = {
    substituters = [ "s3://nix-cache?endpoint=https://registry.s" ];
    trusted-public-keys = [ "cache-name:public-key-here..." ];
  };
}
```

## CI/CD 集成

在 CI 流水线中自动构建并推送：

```bash
# 构建
nix build .#nixosConfigurations.myhost.config.system.build.toplevel

# 推送
nix copy --to 's3://nix-cache?endpoint=https://registry.s' ./result
```
