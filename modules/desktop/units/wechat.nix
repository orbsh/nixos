{ pkgs, lib, config, ... }:

let
  prebuilt = import ../../../libs/prebuilt.nix { inherit pkgs lib; };
in {
  options.desktop.wechat = {
    src = prebuilt.mkSrcOption {
      default = {
        url = "http://box.d/nixos/WeChatLinux_x86_64.AppImage";
        hash = "sha256-ZbFSuutgutjU8bjlq/gAse/WHkKUUh1pQFgQFos/wsM=";
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
        # 上游 AppImage 已改成"安装器"形态：squashfs 里只有 AppRun + wechat-payload.tar
        # + install-apparmor.sh。运行时 AppRun 用 pkexec 把 payload 装到
        # /opt/wechat-appimage/app（root、带 flock 与 digest 校验），再从那儿启动。
        # store 只读、也不该在包安装时提权，所以绕过安装器：直接展开 payload，
        # 在 FHS 环境里复现 AppRun 装完之后的那条启动线
        # （APPDIR=<app> PATH=<app>:$PATH exec <app>/wechat）。
        # apparmor profile 只在内核限制非特权 userns 时才需要，本机不启用。
        appimage = prev.appimageTools.extract {
          pname = "wechat";
          version = "custom";
          src = srcFile;
        };

        payload = prev.runCommandLocal "wechat-custom-payload" {
          nativeBuildInputs = [ prev.gnutar ];
        } ''
          mkdir -p $out/opt/wechat-appimage/app
          tar -xf ${appimage}/wechat-payload.tar -C $out/opt/wechat-appimage/app
        '';

        appDir = "/opt/wechat-appimage/app"; # payload 在 FHS 内的落点

        wechatBase = prev.buildFHSEnv (
          prev.appimageTools.defaultFhsEnvArgs
          // {
            pname = "wechat";
            version = "custom";
            # payload 不进 rootfs（会多出一份 800M 拷贝）：运行时把它的 /opt
            # 直接 bind 进 FHS，appDir 的路径与上游安装位置保持一致。
            extraBuildCommands = "mkdir -p $out/opt";
            extraBwrapArgs = [ "--ro-bind ${payload}/opt /opt" ];
            targetPkgs = pkgs:
              prev.appimageTools.defaultFhsEnvArgs.targetPkgs pkgs ++ [ pkgs.libsecret ];
            runScript = prev.writeShellScript "wechat-launch" ''
              export APPDIR=${appDir}
              export PATH=${appDir}:$PATH
              exec ${appDir}/wechat "$@"
            '';
          }
        );

        # 输入法：AppImage 里的 Qt 是静态链接的，fcitx5 的 qt 插件（qt6）注入不进去；
        # 上游把 fcitx-qt5 编译进了二进制（third_party/fcitx-qt5），但只有在
        # QT_IM_MODULE=fcitx 时才会加载。不设置就回退 XIM，而这份静态 Qt 不包含
        # xim 插件 —— 结果就是完全打不出中文。与 nixpkgs 的 wechat 同一策略：
        # 按 XMODIFIERS 选 IM module。
        wechatIme = prev.writeShellScriptBin "wechat" ''
          case "''${XMODIFIERS:-}" in
            *@im=fcitx*)
              export QT_IM_MODULE=fcitx
              export GTK_IM_MODULE=fcitx
              ;;
          esac
          exec ${wechatBase}/bin/wechat "$@"
        '';

        # 只暴露带 IM 环境的外壳：bin/wechat + 桌面项/图标都从它出，
        # 不让两套 bin/wechat 同时进 buildEnv（同名冲突）。
        wechatWrapped = prev.runCommandLocal "wechat-custom-wrapped" { } ''
          mkdir -p $out/bin $out/share/applications
          mkdir -p $out/share/icons/hicolor/256x256/apps
          cp ${wechatIme}/bin/wechat $out/bin/wechat
          sed -e 's|^Exec=.*|Exec=wechat %U|' -e 's|^Icon=.*|Icon=wechat|' \
            ${appimage}/wechat.desktop > $out/share/applications/wechat.desktop
          cp ${appimage}/wechat.png $out/share/icons/hicolor/256x256/apps/
        '';
      in {
        wechat = if srcFile != null then wechatWrapped else prev.wechat;
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
