{ pkgs, ... }: {
  # NixOS 的 rustup 包已适配 NixOS，无需额外配置
  # 使用方式：rustup toolchain install stable（会自动使用 NixOS 兼容的二进制）
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
}
