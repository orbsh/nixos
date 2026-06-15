{ config, pkgs, lib, nushellSrc, nushellLocalPath, user, ... }:

let
  developMode = config.programs.developMode;
in
{
  config.home-manager.users.${user} = {
    imports = [
      ({ config, lib, ... }: {
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

        home.file.".config/nushell" = if developMode then {
          # 工作站开发模式：单符号链接指向本地开发目录（out-of-store）
          source = config.lib.file.mkOutOfStoreSymlink nushellLocalPath;
          force = true;
        } else {
          # 服务器/只读模式：从 flake input 正常部署（in-store）
          source = nushellSrc;
          force = true;
          recursive = true;
        };
      })
    ];
  };
}
