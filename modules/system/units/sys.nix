{ pkgs, lib, ... }:

{
  # ── Bootloader: systemd-boot ─────────────────────────────
  boot.loader.systemd-boot = {
    enable = lib.mkDefault true;
    configurationLimit = lib.mkDefault 10;
  };
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.timeout = lib.mkDefault 3;

  # ── Kernel ───────────────────────────────────────────────
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── Network ──────────────────────────────────────────────
  networking.networkmanager.enable = true;

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
  services.xserver.xkb = {
    layout = "us";
    options = "ctrl:swapcaps";
  };
  console.useXkbConfig = true;
}