-- elephant 菜单：最近目录（cwd 历史）
-- 数据来自 nushell cwd_history（LIKE 过滤，经通用桥 elephant_menu.nu 取回 TAB 分隔行）
Name = "cwdhist"
NamePretty = "最近目录"
Icon = "folder-open"
Description = "最近使用的目录（按打开/访问频率）"
SearchName = true
FixedOrder = true   -- 保留脚本返回的 count-desc（按使用频率）顺序，不被 elephant 字母序打乱
Action = "bash -c 'cd \"%VALUE%\" && neovide --maximized --vsync'"

function GetEntries(query)
    local bridge = (os.getenv("HOME") or "~") .. "/.config/elephant/scripts/elephant_menu.nu"
    local q = query or ""
    local handle = io.popen("nu " .. bridge .. " cwdhist " .. tostring(q))
    if not handle then return {} end
    local entries = {}
    for line in handle:lines() do
        local t = {}
        for f in (line .. "\t"):gmatch("(.-)\t") do t[#t + 1] = f end
        if #t >= 3 then
            table.insert(entries, { Text = t[1], Subtext = t[2], Value = t[3] })
        end
    end
    handle:close()
    return entries
end