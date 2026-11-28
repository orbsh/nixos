--!nonstrict
-- 「最近目录」launcher provider。
--
-- 一级：目录列表（`cwdhist.py list` 的 "PATH<TAB>描述"）。
-- 二级：选中某个目录后不直接打开，而是把该目录路径本身作为子查询交回来，列出
--       三种打开方式（herdr / neovide / 文件管理器），再选一个才真正执行。
--
-- 为什么用 query 下钻而不是多键位动作：Noctalia 的 LauncherResult 只有单一激活入口
-- onActivate(id)，没有 walker 那种 action + bind 的组合键。
-- 为什么子查询用「路径本身」而不是 act: 之类的标记：宿主会拿当前输入文本再过滤一遍
-- 结果（和内置 /win 一样，标题或描述命中即可），标记文本匹配不到任何动作行，会直接
-- 显示 No results。路径本身出现在动作行的描述里，过滤就通得过。
-- 计数累加与具体命令都在 cwdhist.py 的 act 子命令里，换打开方式只改那个脚本。

local HOME = noctalia.getenv("HOME") or ""
local HELPER = HOME .. "/.config/noctalia/cwdhist.py"

local ACTIONS = {
  { mode = "herdr",   title = "用 herdr 打开",      subtitle = "新建/复用该目录的 workspace 并切过去", glyph = "layout-grid" },
  { mode = "neovide", title = "用 neovide 打开",    subtitle = "在该目录启动 neovide",                 glyph = "code" },
  { mode = "files",   title = "在文件管理器里打开", subtitle = "xdg-open，跟随当前默认文件管理器",     glyph = "folder-open" },
}

-- 每行 "path<TAB>desc"（描述缺失时整行都是 path）
local function parseLines(stdout)
  local rows = {}
  for line in stdout:gmatch("[^\r\n]+") do
    local tab = line:find("\t", 1, true)
    local path, desc
    if tab then
      path = line:sub(1, tab - 1)
      desc = line:sub(tab + 1)
    else
      path, desc = line, ""
    end
    if path ~= "" then
      rows[#rows + 1] = { path = path, desc = desc }
    end
  end
  return rows
end

local function actionMenu(query, path)
  local rows = {}
  for _, a in ACTIONS do
    rows[#rows + 1] = {
      id = a.mode .. ":" .. path,
      title = a.title,
      subtitle = path .. " · " .. a.subtitle,
      glyph = a.glyph,
    }
  end
  launcher.setResults(query, rows)
end

function onQuery(query)
  local text = noctalia.string.trim(query)

  noctalia.runAsync({ "python3", HELPER, "list" }, function(res)
    if not res or res.exitCode ~= 0 then
      launcher.setResults(query, {
        { id = "", title = "目录历史不可用", subtitle = "cwdhist.py list 执行失败", glyph = "alert-triangle" },
      })
      return
    end

    local entries = parseLines(res.stdout)

    -- 输入框里正好是某个历史目录 → 这一层是「打开方式」
    local matched = false
    for _, r in entries do
      if r.path == text then
        matched = true
      end
    end
    if matched then
      actionMenu(query, text)
      return
    end

    -- 否则是目录列表：激活某一项会把该目录路径作为子查询交回来
    local needle = text:lower()
    local rows = {}
    for _, r in entries do
      if needle == "" or r.path:lower():find(needle, 1, true) or r.desc:lower():find(needle, 1, true) then
        rows[#rows + 1] = {
          id = "dir:" .. r.path,
          title = r.path,
          subtitle = r.desc,
          query = r.path,   -- 激活即下钻到打开方式菜单
          glyph = "folder",
        }
      end
    end
    if #rows == 0 then
      rows[1] = { id = "", title = "没有匹配的目录", subtitle = "换个词试试", glyph = "mood-empty" }
    end
    launcher.setResults(query, rows)
  end)
end

function onActivate(id)
  local sep = id:find(":", 1, true)
  if not sep then
    return
  end
  local mode = id:sub(1, sep - 1)
  local path = id:sub(sep + 1)
  if mode == "dir" then   -- 目录项走 query 下钻，不该走到这里
    return
  end
  noctalia.runAsync({ "python3", HELPER, "act", mode, path })
end