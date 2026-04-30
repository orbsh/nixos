{ pkgs, ... }: {
  # ── 字体配置 ───────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      lilex
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts = {
      monospace = [ "Lilex" "Noto Sans Mono CJK SC" ];
      sansSerif = [ "Noto Sans" "Noto Sans CJK SC" ];
    };
  };
}
