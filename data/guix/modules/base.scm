;; modules/base.scm — 基础系统配置模块
;; 对应 NixOS: modules/common/sys.nix + modules/common/base.nix
;;
;; 使用方式:
;;   (load "modules/base.scm")
;;   然后引用 %base-packages, %bootloader, %user-account 等变量

(use-modules
  (gnu)
  (gnu system)
  (gnu bootloader grub)
  (gnu packages bash)
  (gnu packages certs)
  (gnu packages curl)
  (gnu packages file)
  (gnu packages freedesktop)
  (gnu packages git)
  (gnu packages linux)
  (gnu packages nss)
  (gnu packages rsync)
  (gnu packages ssh)
  (gnu packages sudo)
  (gnu packages wget))

;; ── 引导加载器 ───────────────────────────────────────────
(define %bootloader
  (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot/efi"))
    (timeout 3)))

;; ── 内核 ─────────────────────────────────────────────────
(define %kernel linux)  ;; Guix 默认的最新稳定内核

;; ── 文件系统 ─────────────────────────────────────────────
;; ⚠️ 需要在使用此模块的配置中覆盖
(define %file-systems
  (list (file-system
          (device (file-system-label "my-root"))
          (mount-point "/")
          (type "ext4"))
        (file-system
          (device (file-system-label "ESP"))
          (mount-point "/boot/efi")
          (type "vfat"))))

;; ── 交换空间 ─────────────────────────────────────────────
(define %swap-devices '())

;; ── 时区与语言 ───────────────────────────────────────────
(define %timezone "Asia/Shanghai")
(define %locale "zh_CN.UTF-8")

;; ── 用户 ─────────────────────────────────────────────────
(define %user-name "master")
(define %user-account
  (user-account
    (name %user-name)
    (comment "Master User")
    (group "users")
    (home-directory (string-append "/home/" %user-name))
    (supplementary-groups
     '("wheel" "netdev" "audio" "video" "kvm" "input"))
    (shell (file-append bash "/bin/bash"))))

;; ── 基础软件包 ───────────────────────────────────────────
;; 对应 NixOS base.nix 中的 environment.systemPackages
(define %base-packages
  (list
   ;; ── 网络与传输 ──
   git curl wget rsync

   ;; ── 文件与系统工具 ──
   jq tree file unzip

   ;; ── 终端与编辑器 ──
   nushell

   ;; ── 系统运行时 ──
   sudo openssh nss-certs))

;; ── 内核参数 ─────────────────────────────────────────────
;; 对应 NixOS boot.kernel.sysctl
(define %kernel-parameters
  '("vm.swappiness=10"
    "vm.vfs_cache_pressure=50"
    "net.ipv4.tcp_congestion_control=bbr"
    "net.core.default_qdisc=fq"))

;; ── 键盘布局 ─────────────────────────────────────────────
(define %keyboard-layout
  (keyboard-layout "us" #:options '("ctrl:swapcaps")))
