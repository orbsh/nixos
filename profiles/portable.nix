{ pkgs, lib, user, ... }: {
  imports = [
    ../modules/system/core.nix

    ../modules/dev/rescue.nix

    ../modules/desktop/base.nix

    # ../modules/services/virt.nix
    ../modules/services/singbox.nix   # sing-box 代理组件（替代 ladder/mihomo，引入即起效）
    ../modules/services/ferron.nix     # Ferron 3.x 常驻服务（文件下载 + CGI 网关，port 8080）
  ];

  # 移动硬盘不能修改 EFI 变量，否则在宿主机安装时会写到宿主机的 EFI
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # udisks2 用于自动挂载可移动设备
  services.udisks2.enable = true;

  # 自动登录
  services.getty.autologinUser = user;
}
