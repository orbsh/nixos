{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # 不用 rustup：其 rust-analyzer wrapper 会遮蔽 nixpkgs 的二进制，导致无限递归
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    sccache
  ];

  environment.variables = {
    RUSTC_WRAPPER = "sccache";
    CARGO_HOME  = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
  };
}
