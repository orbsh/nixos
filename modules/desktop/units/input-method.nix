{ pkgs, lib, ... }: {
  # ── Input Method: fcitx5 + Rime ──────────────────────
  config = {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = [
          pkgs.fcitx5-gtk
          pkgs.fcitx5-rime
          pkgs.qt6Packages.fcitx5-configtool
          pkgs.qt6Packages.fcitx5-chinese-addons
        ];
      };
    };
  };
}
