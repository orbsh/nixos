self: super: {

  # ── 使用 nushell 官方 musl 二进制 ──────────────────────
  nushell = super.stdenv.mkDerivation {
    pname = "nushell";
    version = "0.113.0";

    src = super.fetchurl {
      url = "https://github.com/nushell/nushell/releases/download/0.113.0/nu-0.113.0-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "sha256-bpTuADU2fEcbNNraV6c15V9WE9l6w/pYwO8kHyKhLt4=";
    };

    installPhase = ''
      mkdir -p $out/bin
      cp nu $out/bin/
      cp nufmt $out/bin/ 2>/dev/null || true
    '';

    doCheck = false;
    doInstallCheck = false;

    meta = {
      description = "A new type of shell (official musl binary)";
      homepage = "https://nushell.sh";
      license = super.lib.licenses.mit;
      platforms = super.lib.platforms.linux;
    };
  };

}
