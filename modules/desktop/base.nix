# 基础桌面预设：便携系统（= mini + apps-extra + rime）
{ pkgs, lib, config, user, ... }: {
  imports = [
    ./mini.nix                    # 继承 mini（apps-core, de-session, greetd, 输入法/字体/可访问性等）
    ./units/apps-extra.nix
    ./units/rime-pinyin.nix       # Rime 拼音层（内部引入 rime-base）
    ./units/rime-wubi.nix         # Rime 五笔层（内部引入 rime-base）
  ];

  # ── 合并各模块的 resume 命令 ───────────────────────
  powerManagement.resumeCommands = config.desktop.inputMethod.resumeCommands;
}