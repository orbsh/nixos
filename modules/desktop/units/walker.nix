# walker: Wayland-native application runner
# https://github.com/abenz1267/walker
{ pkgs, lib, config, user, ... }:

{
  # ── walker 包 ──────────────────────────────────────────
  environment.systemPackages = [
    pkgs.walker
  ];

  # ── walker 配置 ────────────────────────────────────────
  home-manager.users.${user} = {
    xdg.configFile."walker/config.json".source = ../assets/walker/config.json;
  };
}
