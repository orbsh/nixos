{ config, pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    uv
    (python3.withPackages (ps: with ps; [
      virtualenv
      # Web (uvicorn 运行时自动探测 uvloop/httptools/websockets，等于 [standard] extra)
      httpx fastapi uvicorn websockets uvloop httptools watchfiles python-dotenv
      # Async
      aiofile aiostream
      # CLI
      ipython typer
      # Utils
      pydantic pydantic-graph pydantic-settings
      pyparsing jinja2 boltons decorator shortuuid
      # Logging & Codec
      structlog python-json-logger pyyaml ckdl
      # Compression
      zstandard
    ]))
  ] ++ lib.optionals config.programs.developMode [
    ruff     # Python linter & formatter
    ty       # Python type checker
    (python3.withPackages (ps: with ps; [
      debugpy  # Debugger
      pytest   # Testing
      tree-sitter
      tree-sitter-language-pack
    ]))
  ];
}
