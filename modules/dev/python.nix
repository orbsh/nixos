{ pkgs, lib, config, ... }:

let
  cfg = config.dev.python;
in {
  options.dev.python.enable = lib.mkEnableOption "Python 开发工具链";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      uv
      (python3.withPackages (ps: with ps; [
        virtualenv
        # Web
        httpx fastapi uvicorn websockets
        # Async
        aiofile aiostream
        # Dev
        ty debugpy pytest
        # CLI
        ipython typer
        # Data
        polars lancedb

        # Utils
        pydantic pydantic-graph pydantic-settings
        pyparsing jinja2 boltons decorator shortuuid
        # Logging & Codec
        structlog python-json-logger pyyaml
        # Compression
        zstandard
      ]))
    ];
  };
}