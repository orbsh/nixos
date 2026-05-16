{ lib, inputs, dataDir, self, ... }: {

  imports = [
    # ── ISO 专用模块 ─────────────────────────────────
    ./cache.nix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

    # ── 通用基础模块 ─────────────────────────────────
    ../common/sys.nix
    ../common/base.nix
    ../common/users.nix
    ../common/network.nix
    ../common/container.nix
    ../common/extra.nix
  ];

  # ── Home Manager ──────────────────────────────────
  # 提供用户级配置（如 Nushell）
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs dataDir; };
    users.master = {
      imports = [ ../home/shell.nix ../home/common.nix ];
    };
  };

  # ── ISO 镜像构建参数 ──────────────────────────────
  isoImage.volumeID = "my-nixos-live";
  image.fileName = "my-nixos-live.iso";
  isoImage.squashfsCompression = "zstd -Xcompression-level 9";

  # 尝试禁用 USB 混合启动以解除 ISO 尺寸限制（~2.5GB）
  isoImage.makeUsbBootable = lib.mkForce false;

  # ── 引导与文件系统 ────────────────────────────────
  # 强制排除 ZFS（避免内核模块编译报错）
  boot.supportedFilesystems = lib.mkForce [ "xfs" "btrfs" ];

  # 覆盖 sys.nix 中的 bootloader timeout
  boot.loader.timeout = lib.mkForce 10;

  # ── 网络与服务 ────────────────────────────────────
  networking.hostName = "my-nixos-live";
  networking.useDHCP = false;
  networking.usePredictableInterfaceNames = false;
  networking.interfaces.eth0.useDHCP = true;

  services.getty.autologinUser = lib.mkForce "master";

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

  # 启用 flakes 和 SSH 远程管理
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "yes";
  };

  # ── 临时存储与配置挂载 ────────────────────────────
  # LiveCD 读写层（tmpfs）
  fileSystems."/nix/.rw-store" = {
    fsType = "tmpfs";
    options = [ "mode=0755" "nosuid" "nodev" "relatime" "size=14G" ];
    neededForBoot = true;
  };

  # 将当前 Flake 目录挂载到 ISO 的 /etc/nixcfg 方便调试
  environment.etc.nixcfg.source = builtins.filterSource
    (path: type:
      let base = builtins.baseNameOf path; in
      base != ".git" && type != "symlink" && !(lib.hasSuffix ".qcow2" path) && base != "secrets"
    ) self;
}
