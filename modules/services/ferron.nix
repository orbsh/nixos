# Ferron: 轻量级 Web 服务器（常驻服务，文件下载 + CGI 网关）
# 使用 ferron 3.x musl 静态二进制（覆盖 nixpkgs 2.x）
# 配置和 CGI 脚本位于 ./assets/ferron/（box.conf / box.nu / cache.nu / ...）
# 架构（root=configDir, 无符号链接, 目录分割安全模型）：
#   configDir - 配置+脚本目录（root）。默认指向 store 里的 scripts，脚本直接住 root。
#   dataRoot  - 数据基底根（默认 ~/.box；orbit 设成 ~/pub/Assets）。扁平目录:
#                 data/   DATA_ROOT  - data 文件 (upload 读写, 无 token 只读)
#                 hooks/  HOOKS_ROOT - hook 脚本 (setup 读写)
#                 acl/    ACL_ROOT   - ACL 配置 (admin 读写, 含 index.yml)
#                 nixos/  CACHE_ROOT - cache.nu 前向缓存
#   box.nu/cache.nu 通过 DATA_ROOT/HOOKS_ROOT/CACHE_ROOT/ACL_ROOT 环境变量定位，不依赖 root。
{ pkgs, lib, config, user, ... }:

let
  cfg = config.services.ferron;

  ferronVersion = "3.0.0-beta.10";

  # Ferron 3.x 静态二进制来源
  ferronSrc = pkgs.fetchurl {
    url = "https://github.com/ferronweb/ferron/releases/download/${ferronVersion}/ferron-${ferronVersion}-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-aGfkSzGC02elK4hjuQeTFlMsC4kZqFNwSKL/UB7DTo4=";
  };

  # Ferron 脚本目录（Nix store，含 box.conf / box.nu / cache.nu / ...）
  # 直接作为 root=configDir（不可变、无需符号链接）
  ferronScripts = lib.sources.cleanSource ./assets/ferron;

  # box.conf 中占位符替换为绝对路径
  ferronConfig = pkgs.runCommand "ferron-box.conf" {} ''
    sed -e 's|CONFIG_DIR_PLACEHOLDER|${cfg.configDir}|g' \
        -e 's|DATA_ROOT_PLACEHOLDER|${cfg.dataDir}|g' \
        -e 's|HOOKS_ROOT_PLACEHOLDER|${cfg.hooksDir}|g' \
        -e 's|CACHE_ROOT_PLACEHOLDER|${cfg.cacheRoot}|g' \
        -e 's|ACL_ROOT_PLACEHOLDER|${cfg.aclDir}|g' ${ferronScripts}/box.conf > $out
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
        Ferron 配置文件路径。默认从 ./assets/ferron/box.conf 生成（占位符替换为绝对路径）
      '';
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = ferronScripts;
      description = ''
        配置 + 脚本目录（box.conf 的 root）。
        默认指向 store 里的 scripts 目录（不可变），脚本直接存在于 root 内，无需符号链接。
      '';
    };

    dataRoot = lib.mkOption {
      type = lib.types.path;
      default = "/home/${user}/.box";
      description = ''
        数据基底根。含扁平子目录 data/ hooks/ acl/ nixos/。
        orbit 应设成 ~/pub/Assets。
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataRoot}/data";
      description = "data 文件目录（upload 读写, 无 token 只读）";
    };

    hooksDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataRoot}/hooks";
      description = "hook 脚本目录（setup 读写）";
    };

    aclDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataRoot}/acl";
      description = "ACL 配置目录（admin 读写, 含 index.yml）";
    };

    cacheRoot = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataRoot}/nixos";
      description = ''
        cache.nu 前向缓存网关的缓存目录。
        index.yml 索引也放此处。
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

    # ── 目录设置：数据根 + 扁平子目录（configDir=store 自动存在）──
    systemd.tmpfiles.rules = [
      "d ${cfg.dataRoot} 0755 ${user} users -"
      "d ${cfg.dataDir} 0755 ${user} users -"
      "d ${cfg.hooksDir} 0755 ${user} users -"
      "d ${cfg.aclDir} 0755 ${user} users -"
      "d ${cfg.cacheRoot} 0755 ${user} users -"
    ];

    # ── Ferron 守护服务 ──
    systemd.services.ferron = {
      description = "Ferron web server (file download + CGI gateway)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = user;
        WorkingDirectory = cfg.dataRoot;
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