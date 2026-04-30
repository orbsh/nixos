{ pkgs, lib, ... }: {
  # ── Languages & Runtimes ──────────────────────────────────
  environment.systemPackages = with pkgs; [
    # JS/TS Runtime (Primary)
    bun

    # JS/TS 全局工具链（LSP 服务器）
    vscode-langservers-extracted  # JSON/HTML/CSS 语言服务器
    yaml-language-server          # YAML 语言服务器

    # TypeSpec 需手动安装：bun install -g @typespec/compiler @typespec/json-schema
    # 或创建 home-manager 配置管理 bun 全局包

    # Python (with custom ecosystem) + uv
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

    # Rust Development
    rustup
    cargo
    rustc
    rustfmt
    clippy
    rust-analyzer
    sccache

    # Haskell Development
    haskellPackages.ghc
    haskellPackages.cabal-install
    haskellPackages.stack
    haskellPackages.haskell-language-server

    # WebAssembly
    wasmtime

    # C/C++ Build Tools
    gcc
    cmake
    gnumake
    pkg-config

    # K8s & Containers
    kubectl
    kubernetes-helm

    # Data & Debugging
    duckdb
    termshark
  ];

  environment.variables = {
    RUSTC_WRAPPER = "sccache";
  };


  # ── Databases (默认禁用) ─────────────────────────────────
  services.postgresql = {
    enable = false;
  };

  services.surrealdb = {
    enable = false;
  };

}
