# Home Manager 模块聚合入口
# 所有 host 通过 core.nix 导入此文件，获得基础 HM 配置
{ ... }: {
  imports = [
    ./units/home-base.nix
    ./units/home-shell.nix
    ./units/home-nvim.nix
    ./units/home-helix.nix
    ./units/home-git.nix
  ];
}
