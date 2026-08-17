{ pkgs, lib, config, ... }:

{
  options.desktop.wechat = {
    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          narHash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = {
        url = "file:///nix/store/kb48xr54xpbz2vfsi00zigx86snw3jg7-WeChatLinux_x86_64.AppImage";
        narHash = "sha256-SucQpHHs2xW7LNhEi/4il2v1J/YeJfQOpDebpBu+IgE=";
      };
      description = "WeChat 安装包来源（指定 url 和 narHash）。非空时覆盖 nixpkgs 默认版本，设为 null 则回退 nixpkgs。";
    };
  };

  config = let
    cfg = config.desktop.wechat;
    srcFile = if cfg.src != null
      then (builtins.fetchTree {
        type = "file";
        inherit (cfg.src) url narHash;
      }).outPath
      else null;
  in {
    nixpkgs.overlays = [
      (final: prev: let
        wechatBase =
          if srcFile != null
          then let
            extracted = prev.appimageTools.extract {
              pname = "wechat";
              version = "custom";
              src = srcFile;
            };
          in prev.appimageTools.wrapType2 {
            pname = "wechat";
            version = "custom";
            src = srcFile;
            extraPkgs = pkgs: [ pkgs.libsecret ];
            extraInstallCommands = ''
              mkdir -p $out/share/applications
              cp ${extracted}/wechat.desktop $out/share/applications/
              mkdir -p $out/share/icons/hicolor/256x256/apps
              cp ${extracted}/wechat.png $out/share/icons/hicolor/256x256/apps/
              substituteInPlace $out/share/applications/wechat.desktop \
                --replace-fail AppRun wechat
            '';
          }
          else prev.wechat;
      in {
        wechat = wechatBase;
      })
    ];

    environment.systemPackages = with pkgs; [
      wechat
    ];

    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (pkg.pname or "") [
        "wechat"
      ];
  };
}
