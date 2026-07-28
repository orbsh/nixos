# walker: Wayland-native application runner
# https://github.com/abenz1267/walker
# elephant: Data provider service for walker
# https://github.com/abenz1267/elephant
{ pkgs, lib, config, user, ... }:

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

    # GTK4 Vulkan swapchain 警告，用 GL 渲染器消除
    systemd.user.services.walker = {
      Unit = {
        Description = "Walker daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "exec";
        ExecStart = "${pkgs.walker}/bin/walker --gapplication-service";
        Environment = [ "GSK_RENDERER=gl" ];
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
