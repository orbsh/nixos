{ config, pkgs, lib, user, ... }:
let
  kakouneConf = ''
    # ── 基础 ──

    set-option global quiet true                       # 去掉所有 info 消息
    set-option global tabstop 4
    set-option global indent_width 4
    set-option global scrolloff 3,3
    set-option global aligntab false
    set-option global autoreload true
    set-option global readonly true                   # 默认只读，!w 强制写

    # ── 外观 ──
    set-option global ncurses_set_title true
    set-option global ncurses_status_on_top false
    add-highlighter global/number-lines               # 行号
    add-highlighter global/line-columns               # 列号
    add-highlighter global/ show-whitespaces -tabs '|'

    # ── 杂项 ──
    set-option global eolformat unix
    set-option global filetype noindent               # 默认不自动缩进
  '';
in
{
  home-manager.users.${user} = {
    home.packages = [ pkgs.kakoune ];
    xdg.configFile."kak/kakrc".text = kakouneConf;

    # 符号链接 k → kak
    home.sessionPath = [ "$HOME/.local/bin" ];
    home.file.".local/bin/k".source = "${pkgs.kakoune}/bin/kak";
  };
}
