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

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    nushell-config = {
      url = "github:fj0r/nushell";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, disko, disko-stable, home-manager, home-manager-stable, nixos-generators, nushell-config, ... }@inputs:
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
      system = "x86_64-linux";
      specialArgs = { inherit inputs dataDir; hostname = name; ip = attrs.ip; };
      modules = [
        ./hosts/k8s-role.nix
        k8sRoleModules.${attrs.role}
      ];
    };
  in {
    nixosConfigurations = (nixpkgs.lib.mapAttrs mkK8sNode k8sNodes) // {

      workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs dataDir; };
        modules = [
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
        system = "x86_64-linux";
        specialArgs = { inherit inputs dataDir; };
        modules = [
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
        system = "x86_64-linux";
        specialArgs = { inherit inputs dataDir; };
        modules = [
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

    };

    # 自定义 ISO 构建：nix build .#iso
    packages.x86_64-linux.iso = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      format = "install-iso";
      specialArgs = { inherit inputs dataDir; };
      modules = [
        "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

        # 服务器通用模块（不含 nomad）
        ../../modules/common/sys.nix
        ../../modules/common/base.nix
        ../../modules/common/users.nix
        ../../modules/common/network.nix
        ../../modules/common/container.nix
        ../../modules/common/extra.nix

        # ISO 包缓存（所有项目依赖包，安装时无需联网下载）
        ../../modules/iso/cache.nix

        # 内置 disko 及分区工具，live 环境可离线使用
        inputs.disko.nixosModules.disko

        # Home Manager 支持（提供 nushell 等用户级配置）
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs dataDir; };
            users.master = import ./modules/home/shell.nix;
          };
        }

        {
          # ISO 镜像配置
          isoImage.volumeID = "my-nixos-live";
          isoImage.isoName = "my-nixos-live.iso";
          # 使用 zstd 压缩，比 xz 快 6 倍，体积仅大 15%
          isoImage.squashfsCompression = "zstd -Xcompression-level 9";

          # 文件系统支持（xfs 为主，btrfs 可选，无 zfs）
          boot.supportedFilesystems = [ "xfs" "btrfs" ];

          # 网络配置
          networking.hostName = "my-nixos-live";
          networking.useDHCP = false;
          networking.usePredictableInterfaceNames = false;
          networking.interfaces.eth0.useDHCP = true;

          # 局域网发现（avahi/mDNS）
          services.avahi = {
            enable = true;
            nssmdns4 = true;
            publish = {
              enable = true;
              addresses = true;
              domain = true;
              userServices = true;
              workstation = true;
            };
          };

          # 启用 flakes 和 SSH
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          # 临时构建空间（防止 ISO 环境下 /tmp 或 /nix 空间不足）
          fileSystems."/nix/.rw-store" = {
            fsType = "tmpfs";
            options = [ "mode=0755" "nosuid" "nodev" "relatime" "size=14G" ];
            neededForBoot = true;
          };

          # 将当前配置目录挂载到 ISO 的 /etc/nixcfg，方便安装时直接引用
          environment.etc.nixcfg.source = builtins.filterSource
            (path: type:
              let base = builtins.baseNameOf path; in
              base != ".git" && type != "symlink" && !(builtins.hasSuffix ".qcow2" path) && base != "secrets"
            ) ./.;
        }
      ];
    };
  };
}