# Home Manager 扩展模块（工作站/开发环境）
# 包含桌面工具、额外编辑器等
{ ... }: {
  imports = [
    ./units/home-helix.nix
  ];
}
