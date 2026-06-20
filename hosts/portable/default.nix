# 便携式维护系统域
{ inputs, user, lib, dataDir, ... }:

{
  portable = {
    imports = [
      inputs.disko.nixosModules.disko
      ./disk.nix
      ./hardware-configuration.nix
      ../../modules/presets/portable.nix
      ../../modules/services/harmonia.nix
      ../../modules/services/hermes-system.nix
    ];
  };
}
