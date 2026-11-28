-- elephant 菜单：herdr agents + spaces 合并列表
-- 数据来自 python herdr.py（agents 在前，未被 agent 占用的 workspace 补在后，
-- 状态×cwd/git 状态副标题，focused 排同组末位）
Name = "herdr"
NamePretty = "Hermes agents"
Icon = "user-avatars"
Description = "herdr agent/workspace 切换（回车 focus 该 pane 或 workspace）"
SearchName = true
FixedOrder = true
Keywords = { "herdr", "agent", "切换" }

-- 默认 action：先 niri 聚焦 Ghostty 窗口，再按 value 前缀 herdr focus
-- 包 bash -c：elephant 执行 action 不经 shell，裸命令的 ~ 不展开会静默失败
Action = "bash -c 'python3 ~/.config/elephant/scripts/herdr-focus.py \"%VALUE%\"'"

function GetEntries(query)
    local script = (os.getenv("HOME") or "~") .. "/.config/elephant/scripts/herdr.py"
    local handle = io.popen("python3 " .. script .. " agents " .. tostring(query or ""))
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
