# 团队工作站域
{ inputs, user, lib, dataDir, ... }:

{
  # 域级 imports：自动应用到所有成员节点
  imports = [
    ../../modules/presets/workstation-base.nix
  ];

  # 成员：master
  "orbit" = {
    user = "master";
    hostname = "workstation";
    imports = [
      inputs.disko.nixosModules.disko
      ./orbit/hardware.nix
      ./orbit/disk.nix
      ./orbit/wireguard.nix
      ./vivaldi.nix
      ./wanxiang.nix
      ./nushell.nix
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
    hostname = "alice-ws";
    imports = [
      inputs.disko.nixosModules.disko
      ./alice/hardware.nix
    ];
  };

  # 成员 2：Bob
  "team-bob" = {
    user = "bob";
    hostname = "bob-ws";
    imports = [
      inputs.disko.nixosModules.disko
      ./bob/hardware.nix
    ];
  };
}
