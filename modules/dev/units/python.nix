{ config, pkgs, lib, ... }: {
  # ── 共享 Python 环境 option ─────────────────────────────
  # 所有节点只建【一个】 python3 env，独占系统 python3 符号链接。
  # 其他模块可用 extraPackages 向统一 env 追加依赖（避免各自 withPackages 建同名 env 冲突）。
  options.programs.pythonEnv.extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [];
    description = "追加到统一 python 环境的额外 Python 包（由其他模块注入）";
  };

  config = {
    # ── 单一 python3 env：内置集 + developMode 增补 + 外部注入 ──
    environment.systemPackages = with pkgs; [
      uv
      (python3.withPackages (ps: with ps;
        [
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
          structlog python-json-logger pyyaml
          # Compression
          zstandard
        ]
        # developMode 增补（并入统一 env，避免第二 env）
        ++ lib.optionals config.programs.developMode [
          debugpy  # Debugger
          pytest   # Testing
          tree-sitter
          tree-sitter-language-pack
        ]
        # 其他模块注入（data-tools 的 polars 等）
        ++ config.programs.pythonEnv.extraPackages
      ))
    ] ++ lib.optionals config.programs.developMode [
      ruff     # Python linter & formatter
      ty       # Python type checker
    ];
  };
}