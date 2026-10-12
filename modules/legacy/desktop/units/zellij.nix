# Zellij 终端复用（独立单元，引入即开启）
{ pkgs, lib, ... }: {
  home.packages = with pkgs; [
    zellij   # 终端复用（Ghostty 启动时自动 attach）
  ];

  # ── Zellij（全环境通用：桌面 + SSH）────────────────────────
  programs.zellij = {
    enable = true;
    enableZshIntegration = true;
  };
  xdg.configFile."zellij/config.kdl".source = lib.mkForce ../../system/assets/zellij/config.kdl;
}
