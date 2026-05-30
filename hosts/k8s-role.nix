{ inputs, dataDir, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    # 硬件配置（安装后由 NixOS 生成，或手动编写）
    # ./hardware-${hostname}.nix

    ../modules/system/sys.nix
    ../modules/system/base.nix
    ../modules/system/nix.nix
    ../modules/system/users.nix
    ../modules/system/network.nix

    ../modules/system/container.nix
    ../modules/system/extra.nix

    # 磁盘配置（按需修改）
    # ./disk-${hostname}.nix
  ];
}
