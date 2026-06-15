{ config, pkgs, lib, ... }: {
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
      # Utils
      pydantic pydantic-graph pydantic-settings
      pyparsing jinja2 boltons decorator shortuuid
      # Logging & Codec
      structlog python-json-logger pyyaml
      # Compression
      zstandard
    ]))
  ] ++ lib.optionals config.programs.developMode [
    pyrefly  # Python LSP (type checker)
    ruff     # Python linter & formatter
  ];
}
