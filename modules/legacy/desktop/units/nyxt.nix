{ pkgs, lib, user, ... }:

{
  # ── nyxt 包 ──────────────────────────────────────────
  environment.systemPackages = [
    pkgs.nyxt
  ];

  # ── nyxt 配置文件 ────────────────────────────────────
  home-manager.users.${user} = {
    xdg.configFile."nyxt/init.lisp".source = ../assets/nyxt/init.lisp;
  };
}
