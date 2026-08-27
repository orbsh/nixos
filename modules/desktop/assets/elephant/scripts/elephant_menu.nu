#!/usr/bin/env nu
# 通用 elephant 菜单 → nushell 桥（数据层）
#
# elephant 的动态菜单只认 Lua（menus 提供者），动态条目必须走 Lua GetEntries()。
# 本脚本把"查数据/生成条目"的活统一交给 nushell：任何菜单的 Lua 只需调用本桥并解析输出即可。
#
# 约定：
#   - 每个菜单一个数据脚本，位于 ~/.config/elephant/scripts/<menu>.nu（由 Nix 一并部署）
#   - 数据脚本输出 TAB 分隔行：<显示名> <TAB> <副标题> <TAB> <绝对路径>
#     显示名可用带 ~ 的相对形态，值为绝对路径（供菜单 Action 的 %VALUE% 直接用）
# 新增菜单 = 加一个 <menu>.nu 数据脚本 + 一段 ~10 行的 menus/<menu>.lua，桥本体不变。
def main [menu: string, ...rest: string] {
    let data = [$env.HOME "/.config/elephant/scripts/" $menu ".nu"] | str join
    if not ($data | path exists) { return }
    ^nu $data ($rest | str join " ")
}