{ pkgs, lib, config, ... }:

let
  cfg = config.dev.rust;
in {
  options.dev.rust.enable = lib.mkEnableOption "Rust 开发工具链";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      rustup
      cargo
      rustc
      rustfmt
      clippy
      rust-analyzer
      sccache
    ];

    environment.variables = {
      RUSTC_WRAPPER = "sccache";
    };
  };
}