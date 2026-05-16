{ inputs, hostname, ip, dataDir, ... }: {
  imports = [
    inputs.disko-stable.nixosModules.disko

    # 硬件配置（安装后由 NixOS 生成，或手动编写）
    # ./hardware-${hostname}.nix

    ../../modules/common/sys.nix
    ../../modules/common/base.nix
    ../../modules/common/users.nix
    ../../modules/common/network.nix

    ../../modules/common/container.nix
    ../../modules/common/extra.nix

    # 磁盘配置（按需修改）
    # ./disk-${hostname}.nix
  ];

  networking.hostName = hostname;

  # ── 网络配置 ──────────────────────────────────────────
  networking.interfaces.eth0.ipv4.addresses = [{
    address = ip;
    prefixLength = 24;
  }];
}
