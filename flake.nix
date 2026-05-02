{
  description = "My NixOS configuration";

  # 统一数据目录前缀（podman/quadlet 服务、rime 词库等）
  # 按需修改为实际路径，如 "/home/master/data"
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";       # 工作站 / vbox / ISO
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";   # 服务器

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko-stable = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-stable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    my-nushell-src = {
      url = "github:fj0r/nushell";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, disko, disko-stable, home-manager, home-manager-stable, my-nushell-src, ... }@inputs:
  let
    # ── 数据目录前缀 ─────────────────────────────────────
    dataDir = "/data";

    # ── K8s 节点定义（从外部配置文件读取） ─────────────────────
    k8sNodes = import ./config/nodes.nix;

    # 角色模块映射
    k8sRoleModules = {
      control = ./modules/server/k8s-control.nix;
      worker  = ./modules/server/k8s-worker.nix;
      combo   = [ ./modules/server/k8s-control.nix ./modules/server/k8s-worker.nix ];
    };

    # K8s 节点生成函数
    mkK8sNode = name: attrs: nixpkgs-stable.lib.nixosSystem {
      specialArgs = { inherit inputs dataDir; hostname = name; ip = attrs.ip; };
      modules = [
        { nixpkgs.hostPlatform = "x86_64-linux"; }
        ./hosts/k8s-role.nix
        k8sRoleModules.${attrs.role}
      ];
    };
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
              users.master = import ./modules/home/workstation;
            };
          }
        ];
      };

      server = nixpkgs-stable.lib.nixosSystem {
        specialArgs = { inherit inputs dataDir; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/server
          home-manager-stable.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs dataDir; };
              users.master = import ./modules/home/server;
            };
          }
        ];
      };

      vbox = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs dataDir; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./hosts/vbox
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs dataDir; };
              users.master = import ./modules/home/workstation;
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
              users.master = {
                imports = [ ./modules/home/shell.nix ];
                home.stateVersion = "26.05";
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
