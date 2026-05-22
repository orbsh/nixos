;; workstation.scm — Guix System 工作站配置
;; 对应 NixOS: hosts/workstation/default.nix + 各模块
;;
;; 使用方法:
;;   sudo guix system reconfigure workstation.scm
;;
;; ⚠️ 注意: 这是一个研究参考配置，基于 NixOS 配置结构转换而来。
;;    Guix 的 Scheme 语法与 Nix 语言差异较大，部分细节需要调整。

(use-modules
  (gnu)
  (gnu system)
  (gnu system linux-initrd)
  (gnu bootloader grub)
  (gnu services)
  (gnu services base)
  (gnu services desktop)
  (gnu services networking)
  (gnu services ssh)
  (gnu services sound)
  (gnu packages admin)
  (gnu packages bash)
  (gnu packages certs)
  (gnu packages compression)
  (gnu packages curl)
  (gnu packages file)
  (gnu packages fonts)
  (gnu packages freedesktop)
  (gnu packages git)
  (gnu packages linux)
  (gnu packages networking)
  (gnu packages nss)
  (gnu packages package-management)
  (gnu packages rsync)
  (gnu packages ssh)
  (gnu packages sudo)
  (gnu packages tls)
  (gnu packages wget)
  (srfi srfi-1))

;; ── 主机名 ───────────────────────────────────────────────
(define %host-name "workstation")

;; ── 文件系统 ─────────────────────────────────────────────
;; ⚠️ 请根据实际磁盘情况修改 device 和 type
;; 可用 (uuid "xxxx-xxxx") 代替 (file-system-label "...")
(define %file-systems
  (list (file-system
          (device (file-system-label "my-root"))  ;; ← 修改这里
          (mount-point "/")
          (type "ext4"))
        (file-system
          (device (file-system-label "ESP"))       ;; ← 修改这里
          (mount-point "/boot/efi")
          (type "vfat"))))

;; ── 交换空间 ─────────────────────────────────────────────
(define %swap-devices
  '())  ;; 示例: (list (swap (uuid "xxx-xxx-xxx")))

;; ── 引导加载器 ───────────────────────────────────────────
(define %bootloader
  (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot/efi"))   ;; EFI 分区挂载点
    (timeout 3)))

;; ── 时区与语言 ───────────────────────────────────────────
(define %timezone "Asia/Shanghai")

;; ── 用户 ─────────────────────────────────────────────────
(define %user-name "master")
(define %user-account
  (user-account
    (name %user-name)
    (comment "Master User")
    (group "users")
    (home-directory (string-append "/home/" %user-name))
    (supplementary-groups
     '("wheel" "netdev" "audio" "video" "kvm" "input" "lp"))
    (shell (file-append bash "/bin/bash"))))

;; ── 软件包 ───────────────────────────────────────────────
;; 对应 NixOS: base.nix + fonts.nix + dev 工具
(define %packages
  (list
   ;; ── 基础 CLI（对应 base.nix） ──
   sudo openssh git curl wget rsync
   jq tree file unzip fd ripgrep
   nushell nss-certs

   ;; ── 字体（对应 fonts.nix） ──
   font-dejavu
   font-noto
   font-noto-cjk
   font-noto-emoji

   ;; ── Nerd Fonts ──
   ;; Guix 主仓库不包含 nerd-fonts 包集。
   ;; 替代方案:
   ;;   1. 手动下载放到 ~/.local/share/fonts/
   ;;   2. 用 guix pull + 自定义渠道
   ;;   3. 在配置文件中写 (origin ...) 自行打包
   ;;
   ;; NixOS 中有:
   ;;   nerd-fonts.jetbrains-mono
   ;;   nerd-fonts.monaspace

   ;; ── 桌面运行时 ──
   polkit
   dbus
   network-manager
   pipewire wireplumber

   ;; ── 开发工具（对应 dev.enable = true） ──
   gcc make pkg-config))

;; ── fontconfig 配置 ──────────────────────────────────────
;; 对应 NixOS fonts.nix 中的 fontconfig.conf + defaultFonts
;; Guix 中通过 /etc/fonts/local.conf 注入自定义配置
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

;; ── 服务 ─────────────────────────────────────────────────
(define %services
  (modify-services %desktop-services

    ;; ── OpenSSH（对应 base.nix: Port 2222, 禁用密码） ──
    (openssh-service-type config =>
      (openssh-configuration
        (inherit config)
        (port-number 2222)
        (password-authentication? #f)
        (permit-root-login #f)))

    ;; ── NetworkManager（对应 sys.nix） ──
    (network-manager-service-type config =>
      (network-manager-configuration
        (inherit config)))

    ;; ── PipeWire（对应 sys.nix: alsa + pulse + jack） ──
    (pipewire-service-type config =>
      (pipewire-configuration
        (inherit config)
        (wireplumber? #t)))

    ;; ── SDDM 显示管理器（对应 desktop.nix） ──
    (sddm-service-type config =>
      (sddm-configuration
        (inherit config)))

    ;; ── Guix 守护进程（国内镜像加速） ──
    (guix-service-type config =>
      (guix-configuration
        (inherit config)
        (substitute-urls
         (append (list "https://mirror.sjtu.edu.cn/guix"
                       "https://ci.guix.gnu.org")
                 %default-substitute-urls))
        (use-substitutes? #t)))

    ;; ── Polkit ──
    (polkit-service-type config =>
      (polkit-configuration (inherit config)))))

;; ── 操作系统声明 ─────────────────────────────────────────
(operating-system
  (host-name %host-name)
  (timezone %timezone)
  (locale "zh_CN.UTF-8")

  ;; 引导
  (bootloader %bootloader)
  (kernel linux)

  ;; 文件系统
  (file-systems %file-systems)
  (swap-devices %swap-devices)

  ;; 用户
  (users (list %user-account))

  ;; 软件包
  (packages %packages)

  ;; 服务
  ;; %desktop-services 是 Guix 预设的桌面服务集合
  ;; 我们用 modify-services 修改它，再追加 fontconfig 配置
  (services
   (append (list (service etc-service-type
                          `(("fonts/local.conf"
                             ,(plain-file "fontconfig-local.conf"
                                          %fontconfig-xml)))))
           %services))

  ;; 内核参数（对应 NixOS sysctl）
  (kernel-parameters
   '("vm.swappiness=10"
     "vm.vfs_cache_pressure=50"
     "net.ipv4.tcp_congestion_control=bbr"
     "net.core.default_qdisc=fq"))

  ;; 键盘布局（对应 sys.nix: us + ctrl:swapcaps）
  (keyboard-layout (keyboard-layout "us" #:options '("ctrl:swapcaps"))))
