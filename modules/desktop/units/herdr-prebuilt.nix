{ pkgs, lib, config, ... }:

let
  prebuilt = import ../../../libs/prebuilt.nix { inherit pkgs lib; };
in {
  options.herdr.prebuilt = {
    src = prebuilt.mkSrcOption {
      default = null;
      description = "herdr 官方预编译二进制来源（指定 url 和 flat hash）。设置后启用 overlay 替换 nixpkgs 版本。";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0";
      description = "预编译二进制版本号（用于包标识）";
    };
  };

  # nixpkgs 源码构建 = Rust + Zig（vendor/libghostty-vt）全量编译，无 prebuilt（cache 404），
  # 且 0.9.1 在 binutils 2.46 下链接失败（ld.bfd: .eh_frame_hdr refers to overlapping FDEs）。
  # 官方 release 二进制为 static-pie 单文件，无运行时依赖，不需要 autoPatchelfHook。
  config = lib.mkIf (config.herdr.prebuilt.src != null) {
    nixpkgs.overlays = [
      (final: prev: {
        herdr = prebuilt.mkPrebuilt {
          pname = "herdr";
          version = config.herdr.prebuilt.version;
          src = config.herdr.prebuilt.src;

          dontUnpack = true;

          install = ''
            mkdir -p $out/bin
            install -m755 $src $out/bin/herdr
          '';

          doCheck = false;
          doInstallCheck = false;

          updateScript = "herdr";

          meta = {
            description = "Agent multiplexer that lives in your terminal (official prebuilt binary)";
            homepage = "https://herdr.dev";
            license = prev.lib.licenses.asl20;
          };
        };
      })
    ];
  };
}