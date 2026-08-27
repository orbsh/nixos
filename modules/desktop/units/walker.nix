# walker: Wayland-native application runner
# https://github.com/abenz1267/walker
# elephant: Data provider service for walker
# https://github.com/abenz1267/elephant
{ pkgs, lib, config, user, ... }:

let
  # 启动脚本：等待 Wayland display 就绪后再启动 walker
  # COSMIC 可能不会及时将 WAYLAND_DISPLAY 导入 systemd 用户环境
  startupScript = pkgs.writeShellScript "walker-startup" ''
    export XDG_RUNTIME_DIR=/run/user/$UID

    for i in $(seq 1 50); do
      wl_display=$(${pkgs.findutils}/bin/find /run/user/$UID -maxdepth 1 -name "wayland-*" -type s 2>/dev/null | head -n 1)
      if [ -n "$wl_display" ]; then
        export WAYLAND_DISPLAY=$(basename "$wl_display")
        break
      fi
      sleep 0.2
    done

    if [ -z "$WAYLAND_DISPLAY" ]; then
      echo "No WAYLAND_DISPLAY found after 10s, exiting" >&2
      exit 1
    fi

    export GSK_RENDERER=gl
    exec ${pkgs.walker}/bin/walker --gapplication-service
  '';
in
{
  # ── walker + elephant 包 ────────────────────────────────
  environment.systemPackages = [
    pkgs.walker
    pkgs.elephant
  ];

  # ── walker 配置 ────────────────────────────────────────
  home-manager.users.${user} = {
    xdg.configFile."walker/config.toml".source = ../assets/walker/config.toml;
    xdg.configFile."walker/themes/default/style.css".source = ../assets/walker/themes/default/style.css;

    # ── elephant：menus 提供者（@ 前缀 · Lua→nushell 通用桥）──
    xdg.configFile."elephant/scripts/elephant_menu.nu".source = ../assets/elephant/scripts/elephant_menu.nu;
    xdg.configFile."elephant/scripts/cwdhist.nu".source = ../assets/elephant/scripts/cwdhist.nu;
    xdg.configFile."elephant/menus/cwdhist.lua".source = ../assets/elephant/menus/cwdhist.lua;

    systemd.user.services.walker = {
      Unit = {
        Description = "Walker daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "exec";
        ExecStart = startupScript;
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # elephant 数据服务（socket-based）
    systemd.user.services.elephant = {
      Unit = {
        Description = "Elephant data provider";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.elephant}/bin/elephant";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
