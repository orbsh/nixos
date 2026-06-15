# 所有 host 共享的 Home Manager 基础配置
# 由 system/home.nix 导入，覆盖 server / k8s / workstation / portable / qemu
{ config, pkgs, lib, inputs, user, ... }: {
  home-manager.users.${user} = {
    home = {
      username = "${user}";
      homeDirectory = "/home/${user}";
    };

    # 让 home-manager 自己管理自己
    programs.home-manager.enable = true;

    # ── Zellij（全环境通用：桌面 + SSH）────────────────────
    programs.zellij = {
      enable = true;
      enableZshIntegration = true;
    };
    xdg.configFile."zellij/config.kdl".source = lib.mkForce ../assets/zellij/config.kdl;

    # 环境变量（全环境通用）
    home.sessionVariables = {
      PAGER   = "glow";
    };
  };
}
