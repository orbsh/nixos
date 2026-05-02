{ pkgs, lib, config, ... }:

let
  cfg = config.dev.data-tools;
in {
  options.dev.data-tools.enable = lib.mkEnableOption "数据与网络调试工具";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      duckdb
      termshark
    ];
  };
}