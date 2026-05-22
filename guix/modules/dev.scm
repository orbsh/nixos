;; modules/dev.scm — 开发工具配置模块
;; 对应 NixOS: modules/dev/ (开发工具链)
;;
;; 提供:
;;   %dev-packages - 开发工具包列表
;;
;; 使用方式:
;;   (load "modules/dev.scm")
;;   然后引用 %dev-packages

(use-modules
  (gnu packages)
  (gnu packages base)
  (gnu packages commencement)
  (gnu packages gcc)
  (gnu packages gdb)
  (gnu packages version-control)
  (gnu packages autotools)
  (gnu packages cmake)
  (gnu packages pkg-config)
  (gnu packages python)
  (gnu packages rust)
  (gnu packages node)
  (gnu packages llvm))

;; ── 开发工具包 ───────────────────────────────────────────
(define %dev-packages
  (list
   ;; ── 编译工具链 ──
   gcc
   make
   pkg-config
   gnumake
   autoconf
   automake
   libtool

   ;; ── 构建系统 ──
   cmake
   meson
   ninja

   ;; ── 调试工具 ──
   gdb
   valgrind
   strace

   ;; ── 版本控制 ──
   git
   gh  ;; GitHub CLI

   ;; ── 语言运行时 ──
   python
   python-pip
   node
   rust
   cargo

   ;; ── LLVM/Clang (可选) ──
   ;; clang-toolchain
   ;; llvm

   ;; ── 容器工具 ──
   ;; podman  ;; 如果需要容器开发
   ;; docker  ;; 非自由软件，Guix 默认不包含
   ))
