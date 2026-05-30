{ config, pkgs, lib, nushellSrc, nushellGitUrl, nushellLocalPath, ... }:

let
  cfg = config.programs.nushell;
  nushellInput = nushellSrc;
in
{
  options.programs.nushell.developMode = lib.mkEnableOption
    "Use symlink + git clone for nushell config (for development)";

  config = lib.mkMerge [
    # Enable bash and auto-launch nushell (safe fallback)
    {
      programs.bash.enable = true;
      programs.command-not-found.enable = false;
      programs.bash.bashrcExtra = ''
        # Auto-launch nushell for interactive shells
        # -t 0: only if stdin is a real TTY (skip for scripts/AI/tools)
        # Without 'exec' so that if nu crashes, we fallback to bash
        if [[ -t 0 && $- == *i* && -z "$NU_SHELL" ]] && command -v nu >/dev/null 2>&1; then
          export NU_SHELL=1
          nu --login
          # 退出码 0 = 用户正常输入 exit → 自动退出 bash（只需一次 exit）
          # 退出码 ≠0 = nu 崩溃（配置不兼容） → 留在 bash 里修复
          [ $? -eq 0 ] && exit
        fi
      '';
    }

    # 工作站开发模式：直接 symlink 到本地开发目录
    (lib.mkIf cfg.developMode {
      home.file.".config/nushell" = {
        source = config.lib.file.mkOutOfStoreSymlink nushellLocalPath;
        force = true;
      };
    })

    # 服务器/只读模式：通过 flake input 部署
    (lib.mkIf (!cfg.developMode) {
      # 整目录符号链接（避免逐个展开文件触发路径检查）
      home.file.".config/nushell" = {
        source = config.lib.file.mkOutOfStoreSymlink nushellInput;
        force = true;  # Overwrite if existing file/directory conflicts
      };
    })
  ];
}
