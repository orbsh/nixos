# hermes-system.nix
# 本地 Hermes Agent 核心网关 + Web Dashboard 的 Systemd 双服务模块
{ config, pkgs, user, ... }:

let
  srcDir = "/home/${user}/world/hermes-agent";

  # 全局依赖库：修复 Python 虚拟环境下各类大模型动态库（C-extensions）缺失造成的 ELF 报错
  runtimeLibs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
    pkgs.glibc
  ];
  ldLibraryPath = pkgs.lib.makeLibraryPath runtimeLibs;

  # 1. 注入加强版系统级 `hermes` 命令行包装器
  hermes-cli = pkgs.writeScriptBin "hermes" ''
    #!/usr/bin/env bash
    if [ ! -d "${srcDir}/.venv" ]; then
      echo "检测到未初始化的环境，正在构建 NixOS 专用的独立 Python venv..."
      ${pkgs.python3}/bin/python -m venv ${srcDir}/.venv
      ${srcDir}/.venv/bin/python -m ensurepip --upgrade 2>/dev/null || true
    fi

    # 注入全局动态链接库路径
    export LD_LIBRARY_PATH="${ldLibraryPath}:$LD_LIBRARY_PATH"

    cd ${srcDir}
    exec ${srcDir}/.venv/bin/hermes "$@"
  '';

in {
  # 注册全局命令与库
  environment.systemPackages = [
    pkgs.python3
    pkgs.git
    pkgs.stdenv.cc.cc.lib
    hermes-cli
  ];

  # 服务公共的基础环境配置项（作为共享模板，不直接实例化）
  systemd.services.hermes-base-env = {
    after = [ "network.target" ];
    path = with pkgs; [ bash coreutils python3 python3Packages.pip git stdenv.cc.cc nodejs ];
    serviceConfig = {
      Type = "simple";
      User = user;
      WorkingDirectory = srcDir;
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = [
        "LD_LIBRARY_PATH=${ldLibraryPath}"
        "PYTHONUNBUFFERED=1"
      ];
      ExecStartPre = pkgs.writeShellScript "hermes-init-prep" ''
        set -e
        cd ${srcDir}
        if [ ! -d ".venv" ]; then
          ${pkgs.python3}/bin/python -m venv .venv
        fi
        .venv/bin/python -m ensurepip --upgrade 2>/dev/null || true
        export LD_LIBRARY_PATH="${ldLibraryPath}:$LD_LIBRARY_PATH"
        .venv/bin/python -m pip install -q -e ".[web]"
      '';
    };
  };

  # ── 服务 1：Hermes 核心智能体网关 (Port: 8642) ──
  systemd.services.hermes-gateway = {
    description = "Hermes Agent Core Gateway Daemon";
    wantedBy = [ "multi-user.target" ];
    inherit (config.systemd.services.hermes-base-env) after path;
    serviceConfig = config.systemd.services.hermes-base-env.serviceConfig // {
      # 每次启动前先清理残留的 gateway 进程/PID 文件，避免 --replace 导致的竞态冲突
      ExecStartPre = pkgs.writeShellScript "hermes-gateway-prep" ''
        set -e
        cd ${srcDir}
        # 尝试优雅停止已有 gateway
        .venv/bin/hermes gateway stop 2>/dev/null || true
        sleep 1
        # 强制清理可能残留的 python gateway 进程
        pkill -f "hermes_cli.main gateway run" 2>/dev/null || true
        pkill -f "hermes gateway run" 2>/dev/null || true
        sleep 1
        # 清理 PID/lock 文件
        rm -f ${srcDir}/*.pid ${srcDir}/.hermes*.pid ${srcDir}/gateway/*.pid 2>/dev/null || true
        # 运行基础初始化（venv + pip install）
        if [ ! -d ".venv" ]; then
          ${pkgs.python3}/bin/python -m venv .venv
        fi
        .venv/bin/python -m ensurepip --upgrade 2>/dev/null || true
        export LD_LIBRARY_PATH="${ldLibraryPath}:$LD_LIBRARY_PATH"
        .venv/bin/python -m pip install -q -e ".[web]"
      '';
      ExecStart = "${srcDir}/.venv/bin/hermes gateway run";
    };
  };

  # ── 服务 2：Hermes Web Dashboard 面板 (Port: 9119) ──
  systemd.services.hermes-dashboard = {
    description = "Hermes Agent Web Dashboard Interface";
    wantedBy = [ "multi-user.target" ];
    requires = [ "hermes-gateway.service" ];
    after = [ "hermes-gateway.service" ];
    inherit (config.systemd.services.hermes-base-env) path;
    serviceConfig = config.systemd.services.hermes-base-env.serviceConfig // {
      # 本地使用 127.0.0.1 可跳过 OAuth 认证要求；如需局域网访问改用 0.0.0.0 并配置 auth 或加 --insecure
      ExecStart = "${srcDir}/.venv/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open --skip-build";
    };
  };
}
