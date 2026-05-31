# Hermes Agent 本地部署指南

## 前提条件

```bash
# 1. 克隆源码到指定路径
git clone https://github.com/NousResearch/hermes-agent ~/world/hermes-agent
```

## 部署

```bash
# 2. 应用 NixOS 配置（注册全局 hermes 命令 + systemd 双服务）
sudo nixos-rebuild switch --flake .#workstation
```

## 使用

```bash
# 3. 交互式初始化配置（任意终端执行）
hermes setup

# 或进行网关多平台接入
hermes gateway setup
```

## 后台服务（双进程架构）

系统包含两个独立服务：
- **hermes-gateway**：核心智能体网关，运行在 8642 端口
- **hermes-dashboard**：Web 可视化面板，运行在 9119 端口（依赖 gateway）

```bash
# 启动仪表盘（会自动连锁拉起底层网关）
sudo systemctl start hermes-dashboard

# 或分别控制
sudo systemctl start hermes-gateway
sudo systemctl start hermes-dashboard

# 查看日志
sudo journalctl -u hermes-gateway -f
sudo journalctl -u hermes-dashboard -f

# 关闭所有后台服务
sudo systemctl stop hermes-dashboard hermes-gateway

# 开机自启（已在配置中通过 wantedBy 默认启用）
sudo systemctl enable hermes-dashboard hermes-gateway
```

访问仪表盘：浏览器打开 `http://localhost:9119`

## 更新

```bash
# 拉取最新代码后重启服务即可自动重建 .venv
cd ~/world/hermes-agent && git pull
sudo systemctl restart hermes-dashboard hermes-gateway
```
