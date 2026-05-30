# hermes-system.nix
# 本地 Hermes Agent 的 Systemd 服务 + 全局 CLI 自动化包裹模块
{ config, pkgs, user, ... }:

let
  srcDir   = "/home/${user}/world/hermes-agent";

  # ── 🌟 新增：包装一个完美的系统级 `hermes` 命令行工具 ──
  hermes-cli = pkgs.writeScriptBin "hermes" ''
    #!/usr/bin/env bash
    # 如果本地依赖环境还没初始化，自动在后台秒级拉起
    if [ ! -d "${srcDir}/.venv" ]; then
      echo "检测到未初始化的环境，正在为您构建 NixOS 下的独立 Python 虚拟环境..."
      ${pkgs.python3}/bin/python -m venv ${srcDir}/.venv
      # NixOS 的 venv 默认不含 pip，先 bootstrap
      ${srcDir}/.venv/bin/python -m ensurepip --upgrade 2>/dev/null || true
    fi

    # 注入修复 Python 动态库缺失的全局环境变量
    export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"

    # 强制跳转到项目目录上下文执行用户输入的后续命令（如 setup, config 等）
    cd ${srcDir}
    exec ${srcDir}/.venv/bin/hermes "$@"
  '';

in {
  # 1. 注册全局命令：让系统任何地方都能直接盲敲 `hermes`
  environment.systemPackages = with pkgs; [
    python3
    stdenv.cc.cc.lib
    hermes-cli  # <-- 注入我们刚刚包装好的无感穿透脚本
  ];

  # 2. 后台守护进程（修正版）
  systemd.services.hermes-agent = {
    description = "Hermes Agent Local Host Daemon";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # 🌟 关键修正 1：显式为 Systemd 服务的执行上下文注入核心工具路径
    path = with pkgs; [
      bash
      coreutils
      python3
      python3Packages.pip
      git
      stdenv.cc.cc
    ];

    serviceConfig = {
      Type = "simple";
      User = user;
      WorkingDirectory = srcDir;

      # 共用同一套隔离且完整的动态链接库与路径
      Environment = [
        "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
        "PYTHONUNBUFFERED=1"
      ];

      # 🌟 关键修正 2：NixOS venv 默认不含 pip，先 ensurepip 再安装
      ExecStartPre = pkgs.writeShellScript "hermes-prep" ''
        set -e # 遇到错误立刻停止运行
        cd ${srcDir}

        if [ ! -d ".venv" ]; then
          ${pkgs.python3}/bin/python -m venv .venv
        fi

        # NixOS 的 venv 默认不含 pip，先 bootstrap
        .venv/bin/python -m ensurepip --upgrade 2>/dev/null || true

        # 使用虚拟环境内的 python -m pip 执行安装
        export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"
        .venv/bin/python -m pip install -q -e .
      '';

      # 服务真正运行的指令：--replace 允许自动替换已有实例，避免重启冲突
      ExecStart = "${srcDir}/.venv/bin/hermes gateway run --replace";

      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
