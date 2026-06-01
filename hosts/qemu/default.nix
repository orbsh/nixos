# QEMU/KVM 虚拟机域
{ inputs, user, lib, dataDir, ... }:

{
  qemu = {
    imports = [
      inputs.disko.nixosModules.disko
      ./disk.nix
      ./hardware-configuration.nix
      ../../modules/presets/qemu.nix
    ];
  };
}
