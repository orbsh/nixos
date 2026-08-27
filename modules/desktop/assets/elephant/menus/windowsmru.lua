-- elephant 菜单：窗口列表 (MRU)
-- 数据来自 nushell windowsmru.nu（niri msg windows，按 focus_timestamp 降序 = 最近使用优先，同 Alt+Tab）
Name = "windowsmru"
NamePretty = "窗口 (MRU)"
Icon = "view-restore"
Description = "打开的窗口，按最近使用排序"
SearchName = true
FixedOrder = true
Keywords = { "window", "windows", "recent", "mru", "switcher", "窗口" }

-- 默认 action：focus 该窗口。注意 niri 需 --id 标志（focus-window --id <id>）
Action = "bash -c 'sock=$(ls /run/user/*/niri.wayland-*.sock 2>/dev/null | head -1); [ -n \"$sock\" ] && NIRI_SOCKET=$sock niri msg action focus-window --id %VALUE%'"

function GetEntries(query)
    local bridge = (os.getenv("HOME") or "~") .. "/.config/elephant/scripts/elephant_menu.nu"
    local q = query or ""
    local handle = io.popen("nu " .. bridge .. " windowsmru " .. tostring(q))
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