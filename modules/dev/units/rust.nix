{ pkgs, inputs, ... }:
{
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
    (pkgs.rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" ];
      targets = [
        "x86_64-unknown-linux-musl"
        "wasm32-wasip1" "wasm32-wasip2" "wasm32-unknown-unknown"
      ];
    })

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
}
