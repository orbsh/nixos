{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";       # 全局默认（工作站 / 服务器 / 所有 K8s 节点）
    # nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";   # [备用] 稳定分支 (当前未使用，保留以备特定主机降级需求)

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
    # disko-stable = {
    #   url = "github:nix-community/disko";
    #   inputs.nixpkgs.follows = "nixpkgs-stable";  # [备用] 稳定版 disko，配合 nixpkgs-stable 使用
    # };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # home-manager-stable = {
    #   url = "github:nix-community/home-manager/release-25.11";
    #   inputs.nixpkgs.follows = "nixpkgs-stable";  # [备用] 稳定版 home-manager，配合 nixpkgs-stable 使用
    # };

    my-nushell-src = {
      url = "github:fj0r/nushell";
      flake = false;
    };
  };

  # outputs 函数参数包含所有输入源（stable 系列已注释，目前仅使用 unstable）
  outputs = { self, nixpkgs, nixos-anywhere, nix2container, disko, home-manager, my-nushell-src, ... }@inputs:
  let
    # ── 统一变量定义 ─────────────────────────────────────
    # 集中管理用户名，dataDir 和 home-manager 自动跟随
    user = "master";
    dataDir = "/home/${user}/data";

    # ── K8s 节点定义（展平 clusters，自动注入 runtime 和 masterIP） ──
    k8sConfig = import ./config/nodes.nix { inherit user dataDir; };
    k8sNodes = k8sLib.flattenClusters k8sConfig.clusters;

    # ── K8s 节点构建工具 ─────────────────────────────────────
    k8sLib = import ./modules/server/k8s-lib.nix { inherit nixpkgs inputs dataDir; };
    mkK8sNode = k8sLib.mkK8sNode;
  in {
    nixosConfigurations = (nixpkgs.lib.mapAttrs mkK8sNode k8sNodes) // {

      workstation = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs dataDir; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/workstation
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;    # 用系统的 nixpkgs，避免二次求值
              useUserPackages = true;  # home 包装进系统 profile
              extraSpecialArgs = { inherit inputs dataDir; };
              users.${user} = import ./modules/home/workstation;
            };
          }
        ];
      };

      server = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs dataDir; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/server
          { networking.hostName = "server"; } # 独立 Server 主机默认名称
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs dataDir; };
              users.${user} = import ./modules/home/server;
            };
          }
        ];
      };

      qemu = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs dataDir; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/qemu
          { networking.hostName = "qemu"; } # 独立 QEMU 主机默认名称
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs dataDir; };
              users.${user} = import ./modules/home/workstation;
            };
          }
        ];
      };

      portable = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs dataDir; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/portable
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs dataDir; };
              users.${user} = {
                imports = [ ./modules/home/shell.nix ./modules/home/common.nix ];
              };
            };
          }
        ];
      };

      # ── ISO 配置（已归档至 modules/iso/default.nix，默认注释掉以防体积报错） ──
      # 如需重新启用：
      # 1. 取消注释下方代码
      # 2. 确保 cache.nix 中的包体积总和小于 2.5GB（或修改构建器支持更大体积）
      #
      # iso = nixpkgs.lib.nixosSystem {
      #   specialArgs = { inherit inputs dataDir; self = ./.; };
      #   modules = [
      #     { nixpkgs.hostPlatform = "x86_64-linux"; }
      #     ./modules/iso
      #   ];
      # };

    };

    # 自定义 ISO 构建：nix build .#iso
    # 使用 nixpkgs 原生 system.build.image（NixOS 25.05+）
    # 注意：需先取消注释上方的 iso 主机配置
    # packages.x86_64-linux.iso = self.nixosConfigurations.iso.config.system.build.image;
  };
}
