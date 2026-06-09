# ADR-009: Harmonia 客户端使用命令行参数配置 substituter

**日期**: 2026-06-09
**状态**: 已采纳

## 问题

新节点部署或配置更新时，需要在使用 harmonia 缓存加速构建的同时，将 harmonia 配置应用到目标节点。问题是：是否应在 NixOS 配置中持久化 `substituters` 地址？

## 约束

- `nixos-rebuild switch` 会先评估配置、构建新系统，然后切换
- NixOS 配置中的 `substituters` 只有在 `switch` 完成后才生效
- 构建过程本身就需要使用 substituter 来拉取包
- 非 root 用户需为 `trusted-user` 才能通过 `--option extra-substituters` 指定缓存源（已在 `nix.nix` 中配置）

这是一个自举问题：需要 substituter 配置已生效才能用它加速构建，但配置本身需要通过构建才能生效。

## 备选方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| 在 NixOS 配置中写入 harmonia 地址 | 配置集中管理 | **自举问题**：配置要 switch 后才生效，但 switch 时就需要用它加速 |
| **命令行 `--option substituters`** | 构建时立即生效，无需先 switch | 每次需手动传参 |
| 先 switch 一次（不用 harmonia），再 switch 第二次 | 配置可持久化 | 第一次构建慢，浪费时间 |

## 决策

**使用命令行参数**，不在 NixOS 配置中持久化 harmonia 地址。

```bash
# 1. 建立 SSH 隧道（如需要）
ssh build-host -NvTR 5101:localhost:5100

# 2. 构建时临时指定 harmonia 为首选缓存
sudo nixos-rebuild switch --flake .#<host> \
  --option substituters 'http://localhost:5101 https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org' \
  --option extra-trusted-public-keys 'harmonia-local:bF/+RpECJWbbE8W7/hu1jWRlkQqu/+cXoVrWFENmqXY='
```

关键点：
- 用 `--option substituters`（替换整个列表），而非 `--option extra-substituters`（追加到末尾）
- `substituters` 列表中靠前的 URL 优先级更高，harmonia 放首位
- `extra-trusted-public-keys` 用追加语义即可（公钥已在全局 `trusted-public-keys` 中）

## 理由

1. **自举问题** — 配置中的 substituter 需要 switch 后才生效，但 switch 本身就需要用它来加速构建
2. **即时生效** — 命令行参数在当前构建过程中立即生效，无需预先 switch
3. **灵活切换** — 不同场景可用不同缓存（本地 harmonia / 公共镜像 / S3），无需改配置
4. **避免首次构建慢** — 新节点第一次 switch 就能用 harmonia，不用先慢速构建一次

## 后果

- 每次需要 harmonia 加速时，需通过命令行参数指定
- 可以建立 SSH 隧道访问远程 harmonia，或直接访问局域网 harmonia
- `docs/binary-cache.md` 需包含完整的 CLI 用法说明
