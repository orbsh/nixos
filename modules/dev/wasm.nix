{ pkgs, lib, config, ... }:

let
  cfg = config.dev.wasm;
in {
  options.dev.wasm.enable = lib.mkEnableOption "WebAssembly 运行时与开发工具";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # WebAssembly
      wasmtime
    ];
  };
}