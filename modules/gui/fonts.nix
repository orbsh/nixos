{ pkgs, ... }: {
  # ── 字体配置 ───────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      lilex
      nerd-fonts.jetbrains-mono
      nerd-fonts.monaspace
    ];
    fontconfig = {
      enable = true;
      # hinting, antialias, rgba removed in newer nixpkgs;
      # using fonts.fontconfig.localConf below instead.
      # ── 默认字体映射 ─────────────────────────────
      defaultFonts = {
        monospace = [ "Lilex" "MonaspiceAr" "Noto Sans Mono CJK SC" ];
        sansSerif = [ "Noto Sans" "Noto Sans CJK SC" ];
        serif     = [ "Noto Serif" "Noto Serif CJK SC" ];
      };
    };
  };

  # Custom fontconfig rules (antialias, hintslight, lcddefault, rgb)
  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
      </match>
      <match target="font">
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
      </match>
      <match target="font">
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
      </match>
      <match target="font">
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
      </match>
    </fontconfig>
  '';
}
