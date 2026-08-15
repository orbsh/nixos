{ pkgs, inputs, ... }:
let
  # —— crate 预热清单：源于 ~/data/docker.io/xy/hub.yaml 的 stacks:rust ——
  # 对齐容器 rust.nu 中 `rust prefetch --stack [experimental frontend ui-leptos
  #   cli codec error meta utils regex parser collections http logging data
  #   storage async concurrency web ecs wasm script system]` 的集合，即 hub.yaml
  # 全量 rust 库栈 crate。新项目直接可用这些 crate，无需现场下载。
  # 改动 hub.yaml 时在此同步（可比对 rust.nu 的 prefetch 调用）。
  rustStackCrates = [
    # experimental
    "dumpster"
    # frontend
    "wasm-bindgen" "wasm-bindgen-futures" "wasm-logger" "gloo-net" "web-sys"
    # ui-leptos
    "leptos" "wee_alloc" "wasm-pack"
    # cli
    "clap" "figment" "knuffel" "tempdir"
    # codec
    "rkyv" "serde" "serde_derive" "typetag" "serde_with" "serde_json_path"
    "serde_json" "postcard" "serde_cbor" "schemars" "serde_yaml" "serde-kdl2"
    "kdl" "toml"
    # error
    "snafu" "anyhow" "thiserror"
    # meta
    "proc-macro2" "syn" "quote" "macro_rules_attribute"
    # utils
    "linkme" "jiff" "bumpalo" "short-uuid" "time" "rand"
    # regex
    "regex" "regex-syntax" "regex-automata"
    # parser
    "nom" "minijinja" "bon" "indoc" "itertools" "derive_more"
    # collections
    "nutype" "dashmap" "indexmap" "maplit" "arc-swap" "bitflags" "num"
    # http
    "url" "reqwest" "scraper" "markdown"
    # logging
    "tracing" "tracing-subscriber" "tracing-serde" "tracing-wasm"
    # data
    "polars" "nalgebra" "linfa" "burn" "plotlars"
    # storage
    "slatedb" "fjall"
    # async
    "tokio" "tokio-util" "tokio-tungstenite" "smol" "async-compat"
    "futures" "futures-util" "async-stream" "async-trait" "async-fs" "apalis"
    # concurrency
    "rayon" "crossbeam" "parking_lot"
    # web
    "axum" "axum-extra" "async-graphql" "async-graphql-axum" "sqlx"
    # ecs
    "specs"
    # wasm
    "wasmtime" "wasmi"
    # script
    "pyo3" "steel-core" "steel-repl"
    # system
    "notify" "listenfd" "libc" "mimalloc"
  ];

  # 哑工程 Cargo.toml：把所有 crate 声明为依赖，cargo fetch 即灌入 ~/.cargo/registry 缓存。
  prewarmCargoToml = builtins.concatStringsSep "\n" (
    [ "[package]"
      "name = \"crate-prewarm\""
      "version = \"0.1.0\""
      "edition = \"2021\""
      ""
      "[dependencies]"
    ]
    ++ map (c: "${c} = \"*\"") rustStackCrates
    ++ [ "" ]
  );

  # 稳定工具链（共享给 systemPackages 与预热服务）
  rustToolchain = pkgs.rust-bin.stable.latest.default.override {
    extensions = [ "rust-src" "rust-analyzer" ];
    targets = [
      "x86_64-unknown-linux-musl"
      "wasm32-wasip1" "wasm32-wasip2" "wasm32-unknown-unknown"
    ];
  };
in {
  # 用 oxalica/rust-overlay 的 rust-bin 提供带 wasm 目标的工具链
  # （对齐 ~/data/docker.io/xy/images/core/rust.nu 的 rustup 方案，但避免 rustup 的
  #   rust-analyzer wrapper 遮蔽 nixpkgs 二进制导致的无限递归坑）
  #
  # distRoot 指向国内镜像（FOD 固定 hash，不影响可复现性）：
  #   rust-overlay 默认从 static.rust-lang.org 直连下载，国内慢/卡。
  #   用 mkRustBin 构造带镜像 distRoot 的 rust-bin overlay。
  #   镜像实测速度（下载 rust-std wasm32 21MB）：
  #     rsproxy.cn          ~5.5MB/s（307 重定向到 CDN，最快）
  #     清华 rustup          ~3.0MB/s
  #     USTC rust-static     ~2.4MB/s
  nixpkgs.overlays = [
    (final: prev: {
      rust-bin = inputs.rust-overlay.lib.mkRustBin {
        distRoot = "https://rsproxy.cn/dist";
      } final;
    })
  ];

  environment.systemPackages = with pkgs; [
    # 工具链：stable + 组件 + wasm/musl 目标（无需 rustup）
    rustToolchain

    # nightly 工具链（按需使用，仅 host target）
    (pkgs.rust-bin.nightly.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" ];
    })

    # 构建缓存
    sccache

    # 常用 cargo 工具（对齐 rust.nu 的 stacks:cargo，nixpkgs 已含）
    bacon
    cargo-bloat
    cargo-edit
    cargo-expand
    cargo-feature
    cargo-pgo
    cargo-rail
    cargo-wasi
    rust-script
    trunk
    wasm-tools
    bugstalker
  ];

  # 注：rust.nu 中另有 cargo-tree / cross / cargo-eval / wit-deps-cli / wit-bindgen-cli，
  # nixpkgs 暂未提供，此处省略（需要时可用 cargo install 补装）。

  environment.variables = {
    RUSTC_WRAPPER = "sccache";
    CARGO_HOME  = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
  };

  # —— hub.yaml rust stacks 的 crate 预热 ——
  # user oneshot：登录时（default.target）把 rustStackCrates 全部灌入 cargo registry 缓存，
  # 幂等（已缓存的不会重下）；可随时 `systemctl --user start rust-crate-prewarm` 手动补烧。
  # 走 ~/.cargo/config.toml 的 Clash 代理，未加 crates 镜像。
  systemd.user.services.rust-crate-prewarm = {
    description = "Pre-fetch hub.yaml rust-stack crates into cargo cache";
    path = [ rustToolchain ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 10;
    };
    script = ''
      proj="$HOME/.cargo/crate-prewarm"
      mkdir -p "$proj"
      cat > "$proj/Cargo.toml" <<'EOF'
${prewarmCargoToml}
EOF
      cd "$proj"
      cargo fetch
    '';
    wantedBy = [ "default.target" ];
  };
}