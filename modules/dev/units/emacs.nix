{ config, pkgs, lib, emacsSrc, emacsLocalPath, user, ... }:

let
  developMode = config.programs.developMode;
in
{
  config.home-manager.users.${user} = {
    imports = [
      ({ config, lib, ... }: let
        # Emacs Python 后端依赖（lsp-bridge 等需要）
        emacsWithPythonDeps = pkgs.python3.withPackages (ps: with ps; [
          epc orjson sexpdata six setuptools paramiko
          rapidfuzz watchdog packaging
        ]);
      in {
        home.packages = with pkgs; [
          emacs-pgtk
          emacsPackages.vterm
          ripgrep
          fd
          tree-sitter
          emacsWithPythonDeps
        ] ++ lib.optionals developMode [
          clang-tools
          typescript-language-server
        ];

        # Emacs 配置目录（XDG 规范）
        home.file.".config/emacs" = if developMode then {
          # 工作站开发模式：符号链接指向本地开发目录
          source = config.lib.file.mkOutOfStoreSymlink emacsLocalPath;
          force = true;
        } else {
          # 服务器/只读模式：从 flake input 部署（单个 symlink 指向 store）
          source = emacsSrc;
          force = true;
        };

        # Emacs 守护进程自启动（systemd user service）
        services.emacs = {
          enable = true;
          client.enable = false;  # 用 xdg.desktopEntries 覆盖，需注入 XDG_RUNTIME_DIR
          startWithUserSession = true;
        };

        # 覆盖 NixOS 自动生成的 emacsclient.desktop，注入 XDG_RUNTIME_DIR
        # COSMIC 桌面启动器不自动设置该变量，导致 emacsclient 找不到 daemon socket
        home.file.".local/share/applications/emacsclient.desktop".text = ''
          [Desktop Entry]
          Categories=Development;TextEditor;
          Comment=Edit text
          Exec=env XDG_RUNTIME_DIR=/run/user/1000 emacsclient -c %F
          GenericName=Text Editor
          Icon=emacs
          Keywords=Text;Editor;
          MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
          Name=Emacs Client
          StartupWMClass=Emacsd
          Terminal=false
          Type=Application
        '';

        # 非开发模式：activation script 预装 Emacs 包
        home.activation.emacsPackageSync = lib.mkIf (!developMode) (
          config.lib.dag.entryAfter ["linkGeneration"] ''
            EMACS_CONFIG="$HOME/.config/emacs"
            EMACS_DATA="$HOME/.local/share/emacs"

            # 检查配置是否有变化
            MARKER="$EMACS_DATA/.elpa-sync-marker"
            CURRENT_HASH=$(find "$EMACS_CONFIG" -type f -name "*.el" -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1)

            if [ -f "$MARKER" ]; then
              OLD_HASH=$(cat "$MARKER")
              if [ "$CURRENT_HASH" = "$OLD_HASH" ]; then
                $DRY_RUN_CMD echo "emacs: no config changes, skipping package sync"
                exit 0
              fi
            fi

            $DRY_RUN_CMD echo "emacs: syncing packages..."
            $DRY_RUN_CMD ${pkgs.emacs-pgtk}/bin/emacs --batch \
              --eval "(require 'package)" \
              --eval "(package-initialize)" \
              --eval "(package-refresh-contents)" \
              -l "$EMACS_CONFIG/init.el" 2>&1 || true

            # 保存当前 hash
            $DRY_RUN_CMD mkdir -p "$EMACS_DATA"
            $DRY_RUN_CMD echo "$CURRENT_HASH" > "$MARKER"
          ''
        );
      })
    ];
  };
}
