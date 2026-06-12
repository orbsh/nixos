{ config, pkgs, lib, nvimSrc, nvimLocalPath, user, ... }:

let
  cfg = config.programs.neovim;
in
{
  options.programs.neovim.developMode = lib.mkEnableOption
    "Use symlink for nvim config (for development)";

  config.home-manager.users.${user} = {
    imports = [
      ({ config, lib, ... }: {
        # 不用 programs.neovim，直接装包（避免 HM 生成默认 init.lua）
        home.packages = with pkgs; [
          neovim
          ripgrep
          fd
        ];

        # 设置默认编辑器
        home.sessionVariables.EDITOR = "nvim";
        home.sessionVariables.VISUAL = "nvim";

        home.file.".config/nvim" = if cfg.developMode then {
          # 工作站开发模式：符号链接指向本地开发目录
          source = config.lib.file.mkOutOfStoreSymlink nvimLocalPath;
          force = true;
        } else {
          # 服务器/只读模式：从 flake input 部署
          source = nvimSrc;
          force = true;
          recursive = true;
        };

        # 非开发模式：activation script 初始化 lazy.nvim 插件
        home.activation.lazyNvimSync = lib.mkIf (!cfg.developMode) (
          config.lib.dag.entryAfter ["linkGeneration"] ''
            NVIM_CONFIG="$HOME/.config/nvim"
            NVIM_DATA="$HOME/.local/share/nvim"

            # 确保 git 在 PATH 中（nvim init.lua 需要）
            export PATH="${pkgs.git}/bin:$PATH"

            # 检查配置是否有变化
            MARKER="$NVIM_DATA/.lazy-sync-marker"
            CURRENT_HASH=$(find "$NVIM_CONFIG/lua" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1)

            if [ -f "$MARKER" ]; then
              OLD_HASH=$(cat "$MARKER")
              if [ "$CURRENT_HASH" = "$OLD_HASH" ]; then
                $DRY_RUN_CMD echo "lazy.nvim: no config changes, skipping sync"
                exit 0
              fi
            fi

            $DRY_RUN_CMD echo "lazy.nvim: syncing plugins..."
            $DRY_RUN_CMD ${pkgs.neovim}/bin/nvim --headless \
              -u "$NVIM_CONFIG/init.lua" \
              -c "Lazy! sync" \
              -c "qa" 2>&1 || true

            # 保存当前 hash
            $DRY_RUN_CMD mkdir -p "$NVIM_DATA"
            $DRY_RUN_CMD echo "$CURRENT_HASH" > "$MARKER"
          ''
        );
      })
    ];
  };
}
