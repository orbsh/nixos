# 上游预编译二进制的公共骨架
#
# 只承担协议：{url, hash} 的 option 形状、FOD 取物（pkgs.fetchurl）、mkDerivation 的
# pname/version 头尾、meta 默认值、清单工具的 updateScript 接线。
# 业务留在站点文件：pinned 三元组字面量（scripts/upstream.yml 按行模板改写它）、
# installPhase 的安装动作、选哪个资产以及为什么选它。
{pkgs, lib}:

let
  # FOD（fetchurl）：产物在 store 即跳过下载，可随闭包推送；
  # 换成 builtins.fetchTree 则是 eval 期取物，命中与否取决于本机 fetcher cache。
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);

  srcSubmodule = {
    options = {
      url = lib.mkOption { type = lib.types.str; };
      hash = lib.mkOption { type = lib.types.str; };
    };
  };
in
rec {
  # { url; hash; } 选项。nullable = true 时 null 表示回退 nixpkgs 版本。
  mkSrcOption = { nullable ? true, default ? null, description }:
    lib.mkOption {
      type = if nullable
        then lib.types.nullOr (lib.types.submodule srcSubmodule)
        else lib.types.submodule srcSubmodule;
      inherit default description;
    };

  # pinned 三元组对应的两个选项：version + src（两者默认都取站点文件的 pinned）
  mkPinOptions = { pinned, description }: {
    version = lib.mkOption {
      type = lib.types.str;
      default = pinned.version;
      description = "预编译二进制版本号（原始定义在模块的 pinned，由清单工具自动改写；host 可覆盖）";
    };
    src = mkSrcOption {
      default = { inherit (pinned) url hash; };
      description = "${description}（原始定义在模块的 pinned；置 null 则回退 nixpkgs 版本）";
    };
  };

  # 预编译包骨架。src 给 { url; hash; } 就走 fetchurl，给现成 derivation 则原样使用；
  # install 是 installPhase 正文，其余属性（sourceRoot / nativeBuildInputs / unpackPhase /
  # dontBuild / stdenv…）原样透传给 mkDerivation。
  mkPrebuilt =
    { pname, version, src, install, meta ? { }, updateScript ? null, stdenv ? pkgs.stdenv, ... }@args:
    stdenv.mkDerivation (
      removeAttrs args [ "pname" "version" "src" "install" "meta" "updateScript" "stdenv" ] // {
        inherit pname version;
        src = if builtins.isAttrs src && src ? url then pkgs.fetchurl { inherit (src) url hash; } else src;
        installPhase = install;
        meta = { platforms = [ "x86_64-linux" ]; mainProgram = pname; } // meta;
      } // lib.optionalAttrs (updateScript != null) {
        passthru = (args.passthru or { }) // {
          updateScript = [ "${python}/bin/python" "${./../scripts/upstream.py}" "bump" updateScript "--write" ];
        };
      }
    );
}