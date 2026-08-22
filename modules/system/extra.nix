# Home Manager 扩展模块（工作站/开发环境）= system 层级的派生层：core ⊂ extra
# 引入 extra = 引入 core + 桌面工具 + 额外编辑器。
# 与 desktop 预设同理：层级式（后层只声明增量，前层经 import 继承）。
{ pkgs, ... }: {
  imports = [
    ./core.nix              # 继承 core（sys/kanata/base/nix/gc/users/network/...）
    ./units/home-helix.nix
  ];
  # 额外的 LSP 和格式化工具
  environment.systemPackages = with pkgs; [
    nil      # Nix LSP
    nufmt    # nushell 格式化
    pandoc   # 通用文档转换
  ];
}
