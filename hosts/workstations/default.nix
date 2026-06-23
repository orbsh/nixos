# 团队工作站域
{ inputs, user, lib, dataDir, ... }:

{
  # 域级 imports：自动应用到所有成员节点
  imports = [
    ../../modules/presets/workstation.nix
    # ./harmonia-cache.nix  # 本地 harmonia 缓存加速
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
      ./wanxiang.nix
      #./vivaldi.nix
      # ./nushell.nix
      ./surreal.nix
      (import ../../libs/registries-gen.nix {
        inherit lib;
        runtime = "podman";
        registriesData = import ./registries.nix;
      })
    ];

    # 用户级环境变量（仅对 orbit 节点的 master 用户生效）
    home-manager.users.${user}.home.sessionVariables.PREFER_ALT = "1";
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
