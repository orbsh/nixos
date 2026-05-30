{ inputs, dataDir, ... }: {
  imports = [
    inputs.disko.nixosModules.disko

    # 硬件配置（安装后由 NixOS 生成，或手动编写）
    # ./hardware-${hostname}.nix

    # ── 核心系统预设 ──
    ../modules/system/core.nix

    # 磁盘配置（按需修改）
    # ./disk-${hostname}.nix
  ];
}
