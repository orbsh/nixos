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
      # ── 渲染配置（匹配 ARCH/EndeavourOS 默认表现） ─────
      hinting.enable = true;
      hinting.autohint = false;
      antialias = true;
      rgba = "rgb";         # LCD 子像素排列
      # ── 自定义 fontconfig（hintslight + lcddefault） ──
      # 对应 ARCH 的 10-hinting-slight.conf 和 11-lcdfilter-default.conf
      conf = [
        ''
          <?xml version="1.0"?>
          <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
          <fontconfig>
            <!-- hintstyle: slight（ARCH 默认） -->
            <match target="font">
              <edit name="hintstyle" mode="assign">
                <const>hintslight</const>
              </edit>
            </match>
            <!-- lcdfilter: default（ARCH 默认） -->
            <match target="font">
              <edit name="lcdfilter" mode="assign">
                <const>lcddefault</const>
              </edit>
            </match>
          </fontconfig>
        ''
      ];
      # ── 默认字体映射 ─────────────────────────────
      defaultFonts = {
        monospace = [ "Lilex" "MonaspiceAr" "Noto Sans Mono CJK SC" ];
        sansSerif = [ "Noto Sans" "Noto Sans CJK SC" ];
        serif     = [ "Noto Serif" "Noto Serif CJK SC" ];
      };
    };
  };
}
