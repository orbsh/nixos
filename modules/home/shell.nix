{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.programs.nushell;
  nushellDir = "${config.home.homeDirectory}/Configuration/nushell";
in
{
  options.programs.nushell.developMode = lib.mkEnableOption
    "Use symlink + git clone for nushell config (for development)";

  config = lib.mkMerge [
    # 始终启用 nushell
    { programs.nushell.enable = true; }

    # 工作站开发模式：符号链接 + 自动克隆
    (lib.mkIf cfg.developMode {
      home.file.".config/nushell".source =
        config.lib.file.mkOutOfStoreSymlink nushellDir;

      home.activation.cloneNushellConfig = ''
        if [ ! -d "${nushellDir}/.git" ]; then
          $DRY_RUN_CMD git clone https://github.com/fj0r/nushell.git "${nushellDir}"
        fi
      '';
    })

    # 服务器/只读模式：通过 flake input 部署
    (lib.mkIf (!cfg.developMode) {
      xdg.configFile."nushell".source = "${inputs.nushell-config}";
    })
  ];
}