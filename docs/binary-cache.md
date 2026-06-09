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

## 前提：trusted-users

`modules/system/units/nix.nix` 已配置 `trusted-users = [ "root" user ]`，允许普通用户通过 `--option extra-substituters` 指定额外缓存源。

## 客户端配置

### 为什么使用命令行参数

配置中的 `substituters` 只有在 `switch` 后才生效，但 `switch` 构建时就需要用它加速。这是自举问题（bootstrap problem）。

因此使用命令行参数，在构建时临时指定 harmonia 地址。

### SSH 隧道访问远程 harmonia

如果 harmonia 不在本地网络，可通过 SSH 隧道转发：

```bash
# 在客户端执行，将远程 5100 端口映射到本地 5101
ssh <harmonia-host> -NvTR 5101:localhost:5100
```

### 构建时指定 harmonia 缓存

```bash
# 使用命令行参数临时指定 harmonia 为首选缓存
sudo nixos-rebuild switch --flake .#<host> \
  --option substituters 'http://localhost:5101 https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org' \
  --option extra-trusted-public-keys 'harmonia-local:bF/+RpECJWbbE8W7/hu1jWRlkQqu/+cXoVrWFENmqXY='
```

**关键点：**
- `--option substituters` 替换整个列表，harmonia 放首位优先级最高
- `--option extra-substituters` 追加到末尾，优先级最低
- `extra-trusted-public-keys` 追加公钥（已在全局配置中，可省略）

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
