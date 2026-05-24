;; modules/desktop.scm — 桌面环境配置模块
;; 对应 NixOS: modules/gui/desktop.nix + sys.nix (audio, polkit)
;;
;; 提供:
;;   %desktop-packages   - 桌面相关软件包
;;   %desktop-services   - 修改后的桌面服务列表
;;
;; 使用方式:
;;   (load "modules/desktop.scm")
;;   然后引用 %desktop-packages 和 %desktop-services

(use-modules
  (gnu)
  (gnu services)
  (gnu services desktop)
  (gnu services networking)
  (gnu services sound)
  (gnu services ssh)
  (gnu packages freedesktop)
  (gnu packages networking)
  (gnu packages wm))

;; ── 桌面软件包 ───────────────────────────────────────────
(define %desktop-packages
  (list
   ;; ── 显示管理器 ──
   sddm

   ;; ── Wayland 合成器 ──
   ;; Hyprland 在 Guix 中有包，但没有 service-type
   ;; 需要通过 XDG session 或手动启动
   hyprland

   ;; ── 音频 ──
   pipewire
   ;; wireplumber  ;; 会话管理器（可能需要验证包名）

   ;; ── 系统运行时 ──
   polkit
   dbus
   network-manager))

;; ── 桌面服务 ─────────────────────────────────────────────
;; 基于 (gnu services desktop) 的 %desktop-services 进行修改
;; 对应 NixOS 中的 services.displayManager, services.pipewire 等
(define %custom-desktop-services
  (modify-services %desktop-services

    ;; ── SDDM 显示管理器 ──
    ;; 对应 NixOS services.displayManager.sddm.enable
    (sddm-service-type config =>
      (sddm-configuration
        (inherit config)))

    ;; ── PipeWire 音频 ──
    ;; 对应 NixOS services.pipewire (alsa + pulse + jack)
    (pipewire-service-type config =>
      (pipewire-configuration
        (inherit config)
        (wireplumber? #t)))

    ;; ── OpenSSH ──
    ;; 对应 NixOS services.openssh (Port 2222, 禁用密码)
    (openssh-service-type config =>
      (openssh-configuration
        (inherit config)
        (port-number 2222)
        (password-authentication? #f)
        (permit-root-login #f)))

    ;; ── NetworkManager ──
    (network-manager-service-type config =>
      (network-manager-configuration
        (inherit config)))

    ;; ── Polkit ──
    (polkit-service-type config =>
      (polkit-configuration (inherit config)))

    ;; ── Guix 守护进程（国内镜像） ──
    (guix-service-type config =>
      (guix-configuration
        (inherit config)
        (substitute-urls
         (append (list "https://mirror.sjtu.edu.cn/guix"
                       "https://ci.guix.gnu.org")
                 %default-substitute-urls))
        (use-substitutes? #t)))))

;; ── Hyprland 启动说明 ───────────────────────────────────
;; Guix 中的 Hyprland 没有直接的 service-type。
;; 启动方式:
;;   1. 在 SDDM 中选择 Hyprland session
;;   2. 或 TTY 中运行: Hyprland
;;
;; 如需自动启动，可配置 XDG autostart 或使用 greetd 替代 SDDM。
