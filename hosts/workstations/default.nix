# 团队工作站域
{ inputs, user, lib, dataDir, ... }:

let
  # 团队共享基座：桌面环境、通用软件
  baseRole = ../../modules/roles/workstation-base.nix;
in {
  # 成员：master
  "orbit" = {
    user = "master";
    networking.hostName = "workstation";
    imports = [
      inputs.disko.nixosModules.disko
      baseRole
      ./orbit/hardware.nix
      ./orbit/disk.nix
      ./orbit/wireguard.nix
      # ../../modules/flake-srv/harmonia.nix
      (import ../../libs/registries-gen.nix {
        inherit lib;
        runtime = "podman";
        registriesData = import ./registries.nix;
      })
    ];
  };

  # 成员 1：Alice
  "team-alice" = {
    user = "alice";
    networking.hostName = "alice-ws";
    imports = [
      inputs.disko.nixosModules.disko
      baseRole
      ./alice/hardware.nix
    ];
  };

  # 成员 2：Bob
  "team-bob" = {
    user = "bob";
    networking.hostName = "bob-ws";
    imports = [
      inputs.disko.nixosModules.disko
      baseRole
      ./bob/hardware.nix
    ];
  };
}
