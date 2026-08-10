{ pkgs, lib, ... }:

{
  # ── Bootloader: systemd-boot ─────────────────────────────
  boot.loader.systemd-boot = {
    enable = lib.mkDefault true;
    configurationLimit = lib.mkDefault 10;
  };
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = lib.mkDefault 3;

  # ── Audio ────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # ── Security ─────────────────────────────────────────────
  security.polkit.enable = true;

  # ── Input Devices ────────────────────────────────────────
  # 触控板/笔记本输入已移至 common/laptop.nix

  # ── Keymap (TTY & X11/Wayland) ───────────────────────────
  # 注意：caps/ctrl 交换已由 kanata（evdev 层）接管，见 ./kanata.nix。
  # 这里不设 options（避免与 kanata 双重交换）。
  services.xserver.xkb = {
    layout = "us";
  };
  console.useXkbConfig = true;
}