{ pkgs, lib, config, ... }:

let
  cfg = config.programs.eww;
in {
  options.programs.eww.enable = lib.mkEnableOption "Enable eww widget";

  config = lib.mkIf cfg.enable {
    programs.eww = {
      enable = true;
      configDir = ./eww;
    };
  };
}