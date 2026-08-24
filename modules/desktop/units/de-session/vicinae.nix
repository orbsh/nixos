# Vicinae 应用启动器组件单元
# 组件不感知 DE：服务随 de-session 的 <desktop-<de>>.target 拉起（由 deComponents 表集中门控）。
# DE 需要它时：引入本模块 + 在 de-session/default.nix 的 deComponents.<de> 里加 "vicinae.service"。
# 全局键位（Mod+Space）由各 DE 自行绑定（niri 在 config.kdl binds 里 spawn "vicinae" "toggle"）。
{ config, pkgs, lib, user, ... }:

let
  # 启动脚本：WAYLAND_DISPLAY 优先用 de-session xdg-env-bootstrap 注入的，缺失时回退扫 socket
  startupScript = pkgs.writeShellScript "vicinae-startup" ''
    export PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:/run/wrappers/bin:$PATH
    if [ -z "$WAYLAND_DISPLAY" ]; then
      wl=$(find /run/user/$UID -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | head -n 1)
      [ -n "$wl" ] && export WAYLAND_DISPLAY="$(basename "$wl")"
    fi
    exec ${pkgs.vicinae}/bin/vicinae server
  '';
in
{
  options.programs.vicinae = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Vicinae 应用启动器 daemon。默认启用——引入即启用，由 de-session 门控运行时启动";
    };
    proxy = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HTTP 代理地址（插件/专区 store 下载走代理；null = 直连）。工作站常设 127.0.0.1:7890（本机 Clash）";
    };
  };

  config = lib.mkIf config.programs.vicinae.enable {
    # Linux 上 nixpkgs 的 vicinae 包 qtWrapperArgs 固定指向 /run/wrappers/bin/vicinae-input-server，
    # 需 cap_dac_override 能力才会被授予（剪贴板读/按键注入/文本粘贴依赖它；见官方 nixos-module）。
    security.wrappers.vicinae-input-server = {
      source = "${pkgs.vicinae}/libexec/vicinae/vicinae-input-server";
      capabilities = "cap_dac_override+ep";
      owner = "root";
      group = "root";
    };

    home-manager.users.${user} = {
      home.packages = [ pkgs.vicinae ];

      # 常驻 daemon：供 `vicinae toggle`（Unix socket IPC）唤出客户端窗口。
      systemd.user.services.vicinae = {
        Unit = {
          Description = "Vicinae launcher daemon";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = startupScript;
          Restart = "on-failure";
          RestartSec = "3s";
          # 插件/专区 store 下载走代理（proxy 非空时注入；server 进程拉取，故设于此同步 nix-daemon 约定）
          Environment = lib.mkIf (config.programs.vicinae.proxy != null) [
            "http_proxy=${config.programs.vicinae.proxy}"
            "https_proxy=${config.programs.vicinae.proxy}"
            "all_proxy=${config.programs.vicinae.proxy}"
          ];
        };
        # 不设 WantedBy=graphical-session.target —— 仅由 de-session 的 desktop-<de>.target 随对应会话拉起
      };
    };
  };
}