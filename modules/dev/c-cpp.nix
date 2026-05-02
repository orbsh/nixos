{ pkgs, lib, config, ... }:

let
  cfg = config.dev.c-cpp;
in {
  options.dev.c-cpp.enable = lib.mkEnableOption "C/C++ 开发工具链";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gcc
      cmake
      gnumake
      pkg-config
    ];
  };
}