#!/usr/bin/env nu
# cwd 历史数据脚本 —— elephant 菜单 "cwdhist" 的数据源
# 查询语句取自 ~/Configuration/nushell/scripts/cwdhist/mod.nu:31（带 like 过滤，同源保持一致）
# 输出：每行"显示名 \t 副标题 \t 绝对路径"（TAB 分隔，供 Lua 直接 split；value 为绝对路径）
def main [query: string] {
    let db = $env.HOME + "/.local/share/nushell/cwd_history.sqlite"
    if not ($db | path exists) { return }
    # 转义单引号 + 包成 SQL 字面量 '%kw%'（与 mod.nu 的 quote 一致）
    let kw = $query | str replace -a "'" "''"
    let keyword = $"'%($kw)%'"
    let rows = open $db
    | query db $"select cwd, count from cwd_history where cwd like ($keyword) order by count desc limit 50;"
    for r in $rows {
        let cwd = $r.cwd
        # ~ 展开成绝对路径（供菜单 Action 的 %VALUE% 直接用）+ 过滤已不存在的目录
        let abs = if ($cwd | str starts-with "~") {
            $env.HOME + ($cwd | str replace "~" "")
        } else {
            $cwd 
        }
        if ($abs | path exists) {
            print $"($cwd)\t×($r.count)\t($abs)"
        }
    }
}