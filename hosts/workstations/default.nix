# 团队工作站域
{ inputs, user, lib, dataDir, ... }:

{
  # 域级 imports：自动应用到所有成员节点
  imports = [
    ../../profiles/workstation.nix
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
      ./orbit/wifi-mt7925.nix
      ./wanxiang.nix
      #./vivaldi.nix
      #./nushell.nix
      # ../../modules/dev/units/emacs.nix  # 默认禁用，需时取消注释
      (import ../../libs/registries-gen.nix {
        inherit lib;
        runtime = "podman";
        registriesData = import ./registries.nix;
      })
    ];

    # 用户级环境变量（仅对 orbit 节点的 master 用户生效）
    home-manager.users.${user}.home.sessionVariables.PREFER_ALT = "1";

    # orbit 单独：KDL 配置源目录 + 规则数据目录指向本机数据目录（configDir 不落默认 ~/.config）
    services.singbox = {
      configDir = "/home/${user}/data/ladder/singbox-conf";
      ruleDir = "/home/${user}/data/ladder/sing-box/config/rule_sets";
    };
    services.ferron = {
      dataDir = "/home/${user}/pub/Assets";
    };
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
