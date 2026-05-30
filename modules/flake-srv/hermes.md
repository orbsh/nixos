# Hermes Agent 本地部署指南

## 前提条件

```bash
# 1. 克隆源码到指定路径
git clone https://github.com/NousResearch/hermes-agent ~/world/hermes-agent
```

## 部署

```bash
# 2. 应用 NixOS 配置（注册全局 hermes 命令 + systemd 服务）
sudo nixos-rebuild switch --flake .#workstation
```

## 使用

```bash
# 3. 交互式初始化配置（任意终端执行）
hermes setup

# 或进行网关多平台接入
hermes gateway setup
```

## 后台服务

```bash
# 4. 启动守护进程
sudo systemctl start hermes-agent

# 查看日志
sudo journalctl -u hermes-agent -f

# 开机自启
sudo systemctl enable hermes-agent
```

## 更新

```bash
# 拉取最新代码后重启服务即可自动重建 .venv
cd ~/world/hermes-agent && git pull
sudo systemctl restart hermes-agent
```
