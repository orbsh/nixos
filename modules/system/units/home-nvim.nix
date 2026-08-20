{ config, pkgs, lib, nvimSrc, nvimLocalPath, user, ... }:

let
  developMode = config.programs.developMode;

  # NixOS + neorg rocks：tree-sitter 解析器（norg.so 等）是 luarocks 预编译的，
  # 运行时 dlopen 需要系统 libstdc++。NixOS 动态链接器默认搜索路径不含它，
  # 必须在 nvim wrapper 注入 LD_LIBRARY_PATH 指向 gcc.cc.lib 才能加载。
  nvimPkg = pkgs.neovim.override {
    # extraMakeWrapperArgs 是拼接进 wrapperArgs 的字符串（makeWrapper 语法）
    extraMakeWrapperArgs = "--prefix LD_LIBRARY_PATH : ${pkgs.gcc.cc.lib}/lib";
  };
in
{
  config.home-manager.users.${user} = {
    imports = [
      ({ config, lib, ... }: {
        # 不用 programs.neovim，直接装包（避免 HM 生成默认 init.lua）
        home.packages = with pkgs; [
          nvimPkg
          ripgrep
          fd
          tree-sitter  # tree-sitter-manager.nvim 需要
        ] ++ lib.optionals developMode [
          lua-language-server
          # neorg 的 luarocks rockspec 依赖（tree-sitter-norg 解析器等）需要系统 luarocks
          # lazy.nvim 检测到系统 luarocks 后用她，而不是 hererocks 自建环境
          lua5_1
          luarocks
        ];

        # 设置默认编辑器
        home.sessionVariables.EDITOR = "nvim";
        home.sessionVariables.VISUAL = "nvim";

        home.file.".config/nvim" = if developMode then {
          # 工作站开发模式：符号链接指向本地开发目录
          source = config.lib.file.mkOutOfStoreSymlink nvimLocalPath;
          force = true;
        } else {
          # 服务器/只读模式：从 flake input 部署（单个 symlink 指向 store）
          source = nvimSrc;
          force = true;
        };

        # 非开发模式：activation script 初始化 lazy.nvim 插件
        home.activation.lazyNvimSync = lib.mkIf (!developMode) (
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
            $DRY_RUN_CMD ${nvimPkg}/bin/nvim --headless \
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
