{
  description = "My NixOS configuration";

  inputs = {
    # 切换稳定版：github:NixOS/nixpkgs/nixos-25.05
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

    my-nushell-config = {
      url = "github:fj0r/nushell";
      flake = true;
    };

    my-emacs-config = {
      url = "github:fj0r/emacs";
      flake = true;
    };

    my-nvim-config = {
      url = "github:fj0r/nvim-lua";
      flake = true;
    };
  };

  outputs = { self, nixpkgs, nixos-anywhere, nix2container, disko, home-manager, my-nushell-config, my-nvim-config, my-emacs-config, ... }@inputs:
  let
    # ── 统一变量定义 ─────────────────────────────────────
    user = "master";
    email = "nash@iffy.me";
    dataDir = "/home/${user}/data";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2Q46WeaBZ9aBkS3TF2n9laj1spUkpux/zObmliHUOI";
    hashedPassword = "$y$j9T$LuChS39drFFK0G9w05zzW1$ni887.E/FpNqKVqlAimC5uAUrtcytrZwgHhw7280fN0";  # mkpasswd -m yescrypt "qwer"

    # 修复变量名中的连字符（Nix 函数参数不支持连字符）
    homeManagerInput = home-manager;

    # ── 共享参数（注入 NixOS + Home Manager） ──────────
    commonArgs = {
      inherit inputs dataDir user email sshPublicKey hashedPassword;
      self = ./.;  # flake 根目录路径
      nushellSrc = my-nushell-config.outPath;
      nushellLocalPath = "/home/${user}/Configuration/nushell";
      nvimSrc = my-nvim-config.outPath;
      nvimLocalPath = "/home/${user}/Configuration/nvim";
      emacsLocalPath = "/home/${user}/Configuration/emacs";
      emacsSrc = my-emacs-config.outPath;
      # 公共 DNS（地理位置相关：中国大陆）
      publicDnsServers = [ "223.5.5.5" "119.29.29.29" "1.1.1.1" ];
      # 全局 stateVersion（NixOS + Home Manager 可独立演进）
      systemStateVersion = "26.05";
      homeStateVersion = "26.05";
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

    # ── nixos-anywhere 专用 ISO ─────────────────────────────
    # 构建命令：nix build .#iso.config.system.build.isoImage
    iso = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs self user email sshPublicKey hashedPassword;
        nushellSrc = my-nushell-config.outPath;
        nushellLocalPath = "/home/${user}/Configuration/nushell";
        nvimSrc = my-nvim-config.outPath;
        nvimLocalPath = "/home/${user}/Configuration/nvim";
        emacsLocalPath = "/home/${user}/Configuration/emacs";
        emacsSrc = my-emacs-config.outPath;
        systemStateVersion = commonArgs.systemStateVersion;
        homeStateVersion = commonArgs.homeStateVersion;
      };
      modules = [
        { nixpkgs.hostPlatform = "x86_64-linux"; }
        ./modules/iso
      ];
    };
  };
}
