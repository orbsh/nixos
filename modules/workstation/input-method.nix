{ pkgs, lib, dataDir, ... }: {
  # ── Input Method: fcitx5 + Rime + 五笔 ─────────────────
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      (fcitx5-rime.override {
        rimeDataPkgs = [ pkgs.rime-data "${dataDir}/rime-wubi" ];
      })
      qt6Packages.fcitx5-chinese-addons
    ];
  };


}