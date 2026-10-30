# hermes-system.nix
# 本地 Hermes Agent 核心网关 + Web Dashboard 的 Systemd 双服务模块
{ config, pkgs, user, ... }:

let
  srcDir = "/home/${user}/world/hermes-agent";

  # 上游 pyproject.toml 依赖已门控 python_version >= '3.14'（openai/certifi 等），
  # 显式钉住 python314，避免 nixpkgs 默认 python3 漂移时 venv 依赖静默装不上。
  python = pkgs.python314;

  # 全局依赖库：修复 Python 虚拟环境下各类大模型动态库（C-extensions）缺失造成的 ELF 报错。
  # 注意：不要把 pkgs.glibc 放进来。venv python 自带匹配的 loader/libc，
  # 经 LD_LIBRARY_PATH 混入另一份 glibc 会触发 GLIBC_PRIVATE 符号错误而崩溃。
  runtimeLibs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];
  ldLibraryPath = pkgs.lib.makeLibraryPath runtimeLibs;

  # 1. 注入加强版系统级 `hermes` 命令行包装器
  #    依赖环境由 Hermes PM 维护（~/.hermes/installs/<id>/environments/<gen>/venv），
  #    launcher 由 `hermes pm install` 生成；不要在 in-tree 自建 .venv ——
  #    PM 提交首个 generation 后会删掉它，且它绑死的解释器会随系统升级漂移。
  hermes-cli = pkgs.writeScriptBin "hermes" ''
    #!/usr/bin/env bash
    # 注入全局动态链接库路径
    export LD_LIBRARY_PATH="${ldLibraryPath}:$LD_LIBRARY_PATH"

    exec ${srcDir}/.hermes/bin/hermes --no-restore-cwd "$@"
  '';

  # 2. `oi` 固定为 hermes 的别名（原 open-interpreter symlink，OI 已移除后回收此快捷键）
  oi-alias = pkgs.runCommand "oi-alias" {} ''
    mkdir -p $out/bin
    ln -s ${hermes-cli}/bin/hermes $out/bin/oi
  '';

in {
  # 注册全局命令与库
  environment.systemPackages = [
    python
    pkgs.git
    pkgs.stdenv.cc.cc.lib
    hermes-cli
    oi-alias
  ];

  # 服务公共的基础环境配置项（作为共享模板，不直接实例化）
  systemd.services.hermes-base-env = {
    after = [ "network.target" ];
    path = with pkgs; [ bash coreutils python314 python314Packages.pip git stdenv.cc.cc nodejs ];
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
      # 依赖环境由 PM 维护；服务启动只校验 launcher，不在启动时解析依赖。
      # 原实现在每次启动跑 pip install -e ".[web]"，而 pip 无法表达 pyproject 的
      # [tool.uv] override：hermes-agent 钉 Pillow==13.0.0、browser-harness 钉
      # pillow==12.3.0，pip 必然 ResolutionImpossible，prep 退出 1 让服务永远起不来。
      ExecStartPre = pkgs.writeShellScript "hermes-init-prep" ''
        set -e
        cd ${srcDir}
        if [ ! -x ".hermes/bin/hermes" ]; then
          echo "缺少 ${srcDir}/.hermes/bin/hermes；先在源码目录执行 hermes pm install 生成 PM 环境与 launcher" >&2
          exit 1
        fi
      '';
    };
  };

  # ── 服务 1：Hermes 核心智能体网关 (Port: 8642) ──
  systemd.services.hermes-gateway = {
    description = "Hermes Agent Core Gateway Daemon";
    wantedBy = [ "multi-user.target" ];
    inherit (config.systemd.services.hermes-base-env) after path;
    serviceConfig = config.systemd.services.hermes-base-env.serviceConfig // {
      # 启动前清理残留的 gateway 进程/PID 文件，避免两个实例抢同一端口
      ExecStartPre = pkgs.writeShellScript "hermes-gateway-prep" ''
        set -e
        cd ${srcDir}
        # 重启即重启：--yes 允许在有活跃会话时停掉旧实例（否则旧实例占着 8642，新实例永远绑不上）
        .hermes/bin/hermes gateway stop --yes 2>/dev/null || true
        sleep 1
        # 清理 PID/lock 文件
        rm -f ${srcDir}/*.pid ${srcDir}/.hermes*.pid ${srcDir}/gateway/*.pid 2>/dev/null || true
      '';
      ExecStart = "${srcDir}/.hermes/bin/hermes gateway run";
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
      ExecStart = "${srcDir}/.hermes/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open --skip-build";
    };
  };
}
