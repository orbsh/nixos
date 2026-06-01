{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    my-nushell-src = {
      url = "github:fj0r/nushell";
      flake = true;
    };
  };

  outputs = { self, nixpkgs, nixos-anywhere, nix2container, disko, home-manager, my-nushell-src, ... }@inputs:
  let
    # ── 统一变量定义 ─────────────────────────────────────
    user = "master";
    email = "nash@iffy.me";
    dataDir = "/home/${user}/data";

    # 修复变量名中的连字符（Nix 函数参数不支持连字符）
    homeManagerInput = home-manager;

    # ── 共享参数（注入 NixOS + Home Manager） ──────────
    commonArgs = {
      inherit inputs dataDir user email;
      nushellSrc = my-nushell-src.outPath;
      nushellGitUrl = "https://github.com/${my-nushell-src.owner}/${my-nushell-src.repo}.git";
      nushellLocalPath = "/home/${user}/Configuration/nushell";
    };

    # ── 通用构建器 ─────────────────────────────────────
    mkNode = import ./libs/nixos-builder.nix { inherit nixpkgs commonArgs homeManagerInput; };

    # ── K8s 工具库 ─────────────────────────────────────
    k8sLib = import ./modules/k8s/k8s-libs.nix { inherit nixpkgs inputs commonArgs; };

    # ── 自动发现逻辑 ─────────────────────────────────────
    domains = builtins.attrNames (builtins.readDir ./hosts);

    processDomain = domainName:
      let
        # 导入域定义文件，单独注入 lib（不污染 commonArgs）
        domainDef = import ./hosts/${domainName} (commonArgs // { inherit (nixpkgs) lib; });
        # 域级 imports（自动合并到所有节点）
        domainImports = domainDef.imports or [];
        # 判断是否为集群模式 (包含 nodes 属性)
        nodes = if builtins.hasAttr "nodes" domainDef
          then k8sLib.expandCluster domainName domainDef
          else nixpkgs.lib.removeAttrs domainDef [ "imports" ];
      in
      # 统一映射构建，输出 key 为 domain_nodeName（域名=节点名时简化为单名）
      nixpkgs.lib.mapAttrs' (nodeName: nodeConfig:
        let systemName = if domainName == nodeName then nodeName else "${domainName}_${nodeName}";
            # 域级 imports 合并到节点 imports
            mergedConfig = nodeConfig // {
              imports = (nodeConfig.imports or []) ++ domainImports;
            };
        in nixpkgs.lib.nameValuePair systemName (mkNode ({ inherit nodeName domainName; } // mergedConfig))
      ) nodes;

  in {
    # 合并所有域生成的 nixosConfigurations
    nixosConfigurations = builtins.foldl' (acc: domainName:
      acc // (processDomain domainName)
    ) {} domains;
  };
}
