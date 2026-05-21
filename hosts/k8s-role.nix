{ inputs, dataDir, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    # 硬件配置（安装后由 NixOS 生成，或手动编写）
    # ./hardware-${hostname}.nix

    ../modules/common/sys.nix
    ../modules/common/base.nix
    ../modules/common/nix-tools.nix
    ../modules/common/users.nix
    ../modules/common/network.nix

    ../modules/common/container.nix
    ../modules/common/extra.nix

    # 磁盘配置（按需修改）
    # ./disk-${hostname}.nix
  ];
}
