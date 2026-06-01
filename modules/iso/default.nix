{ pkgs, lib, inputs, user, email, sshPublicKey, nushellSrc, nushellGitUrl, nushellLocalPath, ... }:

let
  # ── Nushell 配置（复制到 store，避免 symlink 导致 xorriso 报错） ─
  nushellConfig = pkgs.runCommand "nushell-config" { } ''
    cp -r ${nushellSrc} $out
  '';
in {

  imports = [
    # ── 最小 ISO 构建器（不依赖 installation-cd-minimal） ──
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/iso-image.nix"
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager

    # ── Nix 生态工具（nh, nixos-anywhere 等） ────
    ../system/units/nix.nix
  ];

  # ── 基础 CLI 工具（复用 base.nix 的包列表） ────
  environment.systemPackages = with pkgs; [
    # ── 网络与传输 ──
    git curl wget rsync socat netcat-openbsd minio-client
    # ── 文件与系统工具 ──
    util-linux jq tree file unzip fd ripgrep bind dust
    # ── 终端与编辑器 ──
    nushell delta zellij helix
    # ── 磁盘与网络 ──
    gptfdisk dosfstools xfsprogs e2fsprogs
    iproute2 net-tools iputils netcat-openbsd openresolv
  ];

  # ── Home Manager（nushell + helix 配置） ────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit user email nushellGitUrl nushellLocalPath; };
    users.${user} = {
      imports = [
        ../home/units/editors.nix
        ../home/units/git.nix
        ../home/units/common.nix
      ];
      home = {
        username = "${user}";
        homeDirectory = "/home/${user}";
      };
      programs.home-manager.enable = true;
      home.enableNixpkgsReleaseCheck = false;

      # ── Nushell 配置（store copy，避免 symlink 报错） ─
      home.file.".config/nushell" = {
        source = nushellConfig;
        force = true;
      };
      programs.bash.enable = true;
      programs.bash.bashrcExtra = ''
        if [[ -t 0 && $- == *i* && -z "$NU_SHELL" ]] && command -v nu >/dev/null 2>&1; then
          export NU_SHELL=1
          nu --login
          [ $? -eq 0 ] && exit
        fi
      '';
    };
  };

  # ── 引导：GRUB EFI + BIOS 双支持 ────────────────
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # ── 内核 ────────────────────────────────────────
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── ISO 构建参数 ────────────────────────────────
  isoImage.volumeID = "NIXOS_AW";
  image.fileName = "nixos-anywhere.iso";
  isoImage.squashfsCompression = "zstd -Xcompression-level 22";
  isoImage.makeUsbBootable = false;
  isoImage.efiSplashImage = null;

  # ── 文件系统 ────────────────────────────────────
  boot.supportedFilesystems = [ "btrfs" "xfs" "vfat" "ntfs" ];

  # ── 网络 ────────────────────────────────────────
  networking.useDHCP = true;

  # ── SSH：默认开启 + 内置公钥 ───────────────────
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

  # ── 用户 ────────────────────────────────────────
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "$y$j9T$LuChS39drFFK0G9w05zzW1$ni887.E/FpNqKVqlAimC5uAUrtcytrZwgHhw7280fN0";
    openssh.authorizedKeys.keys = [ sshPublicKey ];
  };

  users.users.root.openssh.authorizedKeys.keys = [ sshPublicKey ];

  # ── TTY 自动登录 ────────────────────────────────
  services.getty.autologinUser = user;

  # ── 临时存储 ────────────────────────────────────
  fileSystems."/nix/.rw-store" = {
    fsType = "tmpfs";
    options = [ "mode=0755" "nosuid" "nodev" "relatime" "size=8G" ];
    neededForBoot = true;
  };

  # ── 系统版本 ────────────────────────────────────
  system.stateVersion = "26.05";
}
