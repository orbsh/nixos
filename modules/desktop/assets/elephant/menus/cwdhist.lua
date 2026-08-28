-- elephant 菜单：最近目录（cwd 历史）
-- 数据来自 sqlite cwd_history（LIKE 过滤，经 cwdhist.py 取回 TAB 分隔行）
Name = "cwdhist"
NamePretty = "最近目录"
Icon = "folder-open"
Description = "最近使用的目录（按打开/访问频率）"
SearchName = true
FixedOrder = true   -- 保留脚本返回的 count-desc（按使用频率）顺序
Keywords = { "cwd", "history", "recent", "dirs", "directories", "folder" }  -- 英文也能搜到

-- 所有打开方式前置：先自增访问计数（绝对路径 → ~/path upsert，与 shell cd 同源）
local Bump = "python3 ~/.config/elephant/scripts/cwdhist.py enter \"%VALUE%\" ; "

-- 兜底默认 action（个别 entry 无 action 时用）
Action = Bump .. "bash -c 'cd \"%VALUE%\" && neovide --maximized --vsync'"

-- 每条记录都可选的多种打开方式（具名 action）
-- 按键映射在 walker 的 [providers.actions.\"menus:cwdhist\"] 里定义（Enter / ctrl t / ctrl f）
local OPEN_ACTIONS = {
  open_neovide   = Bump .. "bash -c 'cd \"%VALUE%\" && neovide --maximized --vsync'",
  open_alacritty = Bump .. "alacritty --working-directory '%VALUE%'",
  open_cosmic    = Bump .. "cosmic-files '%VALUE%'",
}

function GetEntries(query)
    local script = (os.getenv("HOME") or "~") .. "/.config/elephant/scripts/cwdhist.py"
    local handle = io.popen("python3 " .. script .. " list " .. tostring(query or ""))
    if not handle then return {} end
    local entries = {}
    for line in handle:lines() do
        local t = {}
        for f in (line .. "\t"):gmatch("(.-)\t") do t[#t + 1] = f end
        if #t >= 3 then
            table.insert(entries, {
                Text    = t[1],
                Subtext = t[2],
                Value   = t[3],
                Actions = OPEN_ACTIONS,   -- 多条都能选，用不同按键触发
            })
        end
    end
    handle:close()
    return entries
end
