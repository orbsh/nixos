{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.programs.nushell;
  nushellDir = "${config.home.homeDirectory}/Configuration/nushell";
  nushellInput = inputs.my-nushell-src;
in
{
  options.programs.nushell.developMode = lib.mkEnableOption
    "Use symlink + git clone for nushell config (for development)";

  config = lib.mkMerge [
    # 始终启用 nushell + 插件 (polars / query web)
    # 注：插件放入 home.packages 而非 programs.nushell.plugins，避免与整目录 symlink 冲突
    # {
    #   xdg.enable = true;
    #   programs.nushell.enable = true;
    #   programs.nushell.plugins = [ pkgs.nushellPlugins.polars pkgs.nushellPlugins.query ];
    # }

    # 工作站开发模式：符号链接 + 自动克隆
    (lib.mkIf cfg.developMode {
      # 整目录符号链接
      home.file.".config/nushell".source =
        config.lib.file.mkOutOfStoreSymlink nushellDir;

      # 自动克隆仓库（如果尚未存在）
      home.activation.cloneNushellConfig = ''
        if [ ! -d "${nushellDir}/.git" ]; then
          $DRY_RUN_CMD git clone https://github.com/fj0r/nushell.git "${nushellDir}"
        fi
      '';
    })

    # 服务器/只读模式：通过 flake input 部署
    (lib.mkIf (!cfg.developMode) {
      # 整目录符号链接（避免逐个展开文件触发路径检查）
      home.file.".config/nushell".source =
        config.lib.file.mkOutOfStoreSymlink nushellInput;
    })
  ];
}
