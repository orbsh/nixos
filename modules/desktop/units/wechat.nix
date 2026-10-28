{ pkgs, lib, config, ... }:

{
  options.desktop.wechat = {
    src = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          hash = lib.mkOption { type = lib.types.str; };
        };
      });
      default = {
        url = "http://box.d/nixos/WeChatLinux_x86_64.AppImage";
        hash = "sha256-RX26ArkbAxzdRBLu4HT7v/udnQax5Q/Bgi00hw4RSZA=";
      };
      description = "WeChat 安装包来源（指定 url 和 flat hash）。非空时覆盖 nixpkgs 默认版本，设为 null 则回退 nixpkgs。";
    };
  };

  config = let
    cfg = config.desktop.wechat;
    # FOD（fetchurl）：产物在 store 即跳过下载，可随闭包推送
    srcFile = if cfg.src != null
      then pkgs.fetchurl { inherit (cfg.src) url hash; }
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
