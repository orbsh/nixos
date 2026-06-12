# Home Manager 扩展模块（工作站/开发环境）
# 包含桌面工具、额外编辑器等
{ pkgs, ... }: {
  imports = [
    ./units/home-helix.nix
  ];
  # 额外的 LSP 和格式化工具
  environment.systemPackages = with pkgs; [
    nil      # Nix LSP
    nufmt    # nushell 格式化
    minio-client  # minio-client: mc
  ];
}
