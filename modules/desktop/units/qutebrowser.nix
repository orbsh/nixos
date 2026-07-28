{ pkgs, lib, user, ... }:

{
  # ── qutebrowser 包 ──────────────────────────────────────
  environment.systemPackages = [
    pkgs.qutebrowser
  ];

  # ── qutebrowser 配置文件 ──────────────────────────────────
  home-manager.users.${user} = {
    xdg.configFile."qutebrowser/config.py".source = ../assets/qutebrowser/config.py;
    xdg.configFile."qutebrowser/userscripts".source = ../assets/qutebrowser/userscripts;
  };
}
