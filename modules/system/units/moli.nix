# moli: 面向 AI agent 的 headless 浏览器（Rust 实现，预编译二进制取自 GitHub releases）
# https://github.com/lexmount/moli —— CLI（fetch / serve）+ CDP / WebDriver Classic / BiDi
# 版本与 hash 由 scripts/upstream.yml 的 moli 条目维护（kind = release，flat hash）
{
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs) stdenv;

  version = "1.1.18";

  src = pkgs.fetchurl {
    url = "https://github.com/lexmount/moli/releases/download/v${version}/moli-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-WXFfvbKwFruRNuHttZoqGVwPmEWf0Gc54X7cYtpqSLE=";
  };

  # 官方 release 是 glibc 动态链接的 ELF（DT_NEEDED：libstdc++ / libfontconfig / libz），
  # 靠 autoPatchelfHook 改 interpreter + 补 RPATH，无需包装脚本。
  moli = stdenv.mkDerivation {
    pname = "moli";
    inherit version src;

    nativeBuildInputs = [pkgs.autoPatchelfHook];

    buildInputs = [
      stdenv.cc.cc.lib # libstdc++
      pkgs.fontconfig
      pkgs.zlib
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 moli $out/bin/moli
      install -Dm644 LICENSE-APACHE $out/share/licenses/moli/LICENSE-APACHE
      install -Dm644 LICENSE-MIT $out/share/licenses/moli/LICENSE-MIT
      runHook postInstall
    '';

    # 手动维护的版本 + hash：nu scripts/upstream.nu bump moli --write
    passthru.updateScript = [
      "${pkgs.nushell}/bin/nu"
      "${../../../scripts/upstream.nu}"
      "bump" "moli" "--write"
    ];

    meta = with lib; {
      description = "moli — headless browser for AI agents（DOM-first，按需 layout/paint）";
      homepage = "https://github.com/lexmount/moli";
      license = licenses.asl20;
      mainProgram = "moli";
      platforms = ["x86_64-linux"];
    };
  };
in
  # 模块必须返回 option/config attrset；derivation 作为模块体返回会与
  # module 合并机制形成 config <-> pkgs 无限递归
  {
    environment.systemPackages = [moli];
  }