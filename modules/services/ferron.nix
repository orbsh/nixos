# Ferron: 轻量级 Web 服务器（常驻服务，文件下载 + CGI 网关）
# 使用 ferron 3.x musl 静态二进制（覆盖 nixpkgs 2.x）
# 配置和 CGI 脚本位于 ./assets/ferron/（box.conf / box.nu / bin.nu / ...）
{ pkgs, lib, config, user, ... }:

let
  cfg = config.services.ferron;

  ferronVersion = "3.0.0-beta.10";

  # Ferron 3.x 静态二进制来源
  ferronSrc = pkgs.fetchurl {
    url = "https://github.com/ferronweb/ferron/releases/download/${ferronVersion}/ferron-${ferronVersion}-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-aGfkSzGC02elK4hjuQeTFlMsC4kZqFNwSKL/UB7DTo4=";
  };

  # Ferron 脚本目录（Nix store，含 box.conf / box.nu / bin.nu / ...）
  ferronScripts = lib.sources.cleanSource ./assets/ferron;

  # ferron 不展开 ~，需将 box.conf 中 ~/.box 替换为绝对路径
  ferronConfig = pkgs.runCommand "ferron-box.conf" {} ''
    sed -e 's|~/.box|${cfg.documentRoot}|g' -e 's|PUB_ROOT_PLACEHOLDER|${cfg.pubRoot}|g' ${ferronScripts}/box.conf > $out
  '';

  # CGI 脚本（.nu）所需的外部工具
  cgiPath = lib.makeBinPath [
    pkgs.nushell
    pkgs.coreutils
    pkgs.curl
    pkgs.gnutar
    pkgs.zstd
    pkgs.findutils
    pkgs.ripgrep
    pkgs.jq
  ];

in {
  options.services.ferron = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 8080;
      description = "监听端口";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = ferronConfig;
      description = ''
        Ferron 配置文件路径。默认从 ./assets/ferron/box.conf 生成（~/.box 替换为绝对路径）
      '';
    };

    documentRoot = lib.mkOption {
      type = lib.types.path;
      default = "/home/${user}/.box";
      description = ''
        文档根目录（box.conf 中 root 指向此处）。
        下载文件放在此目录下；CGI 脚本通过 ~/.box/ferron 符号链接访问。
      '';
    };

    pubRoot = lib.mkOption {
      type = lib.types.path;
      default = cfg.documentRoot;
      description = ''
        pub.nu 只读下载服务的根目录。
        通过 CGI 环境变量 PUB_ROOT 传递给 pub.nu 脚本。
      '';
    };
  };

  config = {
    # ── 覆盖 nixpkgs ferron（2.x）为 3.x musl 静态二进制 ──
    nixpkgs.overlays = [
      (final: prev: {
        ferron = prev.stdenv.mkDerivation {
          pname = "ferron";
          version = ferronVersion;
          src = ferronSrc;
          dontBuild = true;

          installPhase = ''
            mkdir -p $out/bin $out/share/ferron
            tar xzf $src -C $out/share/ferron
            for bin in ferron ferron-fmt ferron-kdl2ferron ferron-passwd ferron-precompress ferron-serve; do
              mv $out/share/ferron/$bin $out/bin/ 2>/dev/null || true
            done
            chmod +x $out/bin/*
          '';

          meta = {
            description = "Ferron web server (musl static binary)";
            homepage = "https://github.com/ferronweb/ferron";
            license = prev.lib.licenses.mit;
            platforms = prev.lib.platforms.linux;
          };
        };
      })
    ];

    # ── ferron CLI 工具 ──
    environment.systemPackages = [ pkgs.ferron ];

    # ── 目录设置：文档根目录 + CGI 脚本符号链接 ──
    systemd.tmpfiles.rules = [
      "d ${cfg.documentRoot} 0755 ${user} users -"
      "L+ ${cfg.documentRoot}/ferron - - - - ${ferronScripts}"
    ];

    # ── Ferron 守护服务 ──
    systemd.services.ferron = {
      description = "Ferron web server (file download + CGI gateway)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = user;
        WorkingDirectory = cfg.documentRoot;
        ExecStart = "${pkgs.ferron}/bin/ferron run --config ${cfg.configFile}";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      # CGI 脚本（.nu）需要 nushell + 外部工具
      environment.PATH = lib.mkForce "${cgiPath}:/run/current-system/sw/bin";
    };

    # ── 防火墙放行 ──
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
