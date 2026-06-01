# 通用节点构建器
# 职责：接收节点数据定义 -> 返回 nixosSystem
# 不再区分 Pet/K8s，所有节点统一由此构建
{ nixpkgs, commonArgs, homeManagerInput }:
{ nodeName, domainName ? null, ... }@nodeAttrs:

let
  lib = nixpkgs.lib;

  # 剥离构建器专用字段，剩余的视为 NixOS 配置选项
  # 这些选项将被转换为一个匿名模块并注入模块栈，从而应用 networking.hostName 等配置
  builderKeys = [ "nodeName" "domainName" "imports" "ip" "user" "cni0IP" "isK8sNode" "k8sRole" "runtime" "podCIDR" "masterIP" "hostname" ];
  nodeConfigModule = lib.removeAttrs nodeAttrs builderKeys;

  # ── 基础模块栈 ───────────────────────────────────────
  baseModules = [
    { nixpkgs.hostPlatform = "x86_64-linux"; }
    commonArgs.inputs.disko.nixosModules.disko

    # 核心系统预设 (所有节点默认加载)
    ../modules/system/core.nix

    # Home Manager 集成
    homeManagerInput.nixosModules.home-manager
    {
      "home-manager" = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = commonArgs 
          // lib.optionalAttrs (builtins.hasAttr "user" nodeAttrs) { user = nodeAttrs.user; };
        backupFileExtension = "hm-backup";
        # 关闭 nixpkgs 版本不匹配警告（unstable 滚动更新，版本号永远不一致）
        sharedModules = [
          { home.enableNixpkgsReleaseCheck = false; }
        ];
      };
    }
  ];

  # ── 条件注入：仅当节点提供静态 IP 时配置 eth0 ──────
  networkModule = lib.optional (builtins.hasAttr "ip" nodeAttrs) {
    networking.interfaces.eth0.useDHCP = false;
    networking.interfaces.eth0.ipv4.addresses = [{
      address = nodeAttrs.ip;
      prefixLength = 24;
    }];
  };

  # ── 条件注入：设置主机名 ────────────────────────────
  hostnameModule = lib.optional (builtins.hasAttr "hostname" nodeAttrs) {
    networking.hostName = nodeAttrs.hostname;
  };

  # ── 合并模块 ─────────────────────────────────────────
  finalModules = baseModules ++ networkModule ++ hostnameModule ++ [ nodeConfigModule ] ++ (nodeAttrs.imports or []);

in
nixpkgs.lib.nixosSystem {
  # 注入 K8s 专属模块参数（cni0IP 等）+ 节点级 user 覆盖
  specialArgs = commonArgs 
    // lib.optionalAttrs (builtins.hasAttr "cni0IP" nodeAttrs) { inherit (nodeAttrs) cni0IP; }
    // lib.optionalAttrs (builtins.hasAttr "user" nodeAttrs) { user = nodeAttrs.user; };
  modules = finalModules;
}
