;; modules/fonts.scm — 字体配置模块
;; 对应 NixOS: modules/gui/fonts.nix
;;
;; 提供:
;;   %font-packages     - 字体包列表
;;   %fontconfig-xml    - fontconfig XML 配置内容
;;   %fontconfig-service - 可直接加入 (services ...) 的服务
;;
;; 使用方式:
;;   (load "modules/fonts.scm")
;;   然后引用 %font-packages 和 %fontconfig-service

(use-modules
  (gnu)
  (gnu services)
  (gnu packages fonts))

;; ── 字体包 ───────────────────────────────────────────────
;; 对应 NixOS fonts.nix 中的 fonts.packages
(define %font-packages
  (list
   ;; ── 基础字体 ──
   font-dejavu

   ;; ── Noto 字体家族 ──
   font-noto
   font-noto-cjk
   font-noto-emoji

   ;; ── 等宽字体 ──
   ;; Guix 中有 jetbrains-mono，但没有 nerd-fonts 版本
   ;; font-jetbrains-mono

   ;; ── Lilex ──
   ;; ❌ Guix 主仓库没有 Lilex 字体
   ;; 替代方案: 用 DejaVu 或手动安装
   ))

;; ── fontconfig XML ──────────────────────────────────────
;; 对应 NixOS fonts.nix 中的 fontconfig.conf + defaultFonts
(define %fontconfig-xml
  "<?xml version=\"1.0\"?>
<!DOCTYPE fontconfig SYSTEM \"urn:fontconfig:fonts.dtd\">
<fontconfig>
  <!-- hintstyle: slight（Arch 默认） -->
  <match target=\"font\">
    <edit name=\"hintstyle\" mode=\"assign\">
      <const>hintslight</const>
    </edit>
  </match>

  <!-- lcdfilter: default（Arch 默认） -->
  <match target=\"font\">
    <edit name=\"lcdfilter\" mode=\"assign\">
      <const>lcddefault</const>
    </edit>
  </match>

  <!-- 默认字体映射 -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>DejaVu Sans Mono</family>
      <family>Noto Sans Mono CJK SC</family>
    </prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans CJK SC</family>
    </prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Serif CJK SC</family>
    </prefer>
  </alias>
</fontconfig>")

;; ── fontconfig 服务 ──────────────────────────────────────
;; 可直接加入 (services ...) 列表
;; 对应 NixOS fonts.nix 中的 fonts.fontconfig.conf
(define %fontconfig-service
  (service etc-service-type
    `(("fonts/local.conf"
       ,(plain-file "fontconfig-local.conf"
                    %fontconfig-xml)))))
