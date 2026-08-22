-- =============================================================================
-- Hyprland 声明式配置（Lua 版） —— 由 NixOS 生成，可经符号链接部署到 ~/.config/hypr
-- 替代旧的 hyprland.conf 格式；Hyprland 0.4x Lua 配置 API（hl.*）
-- 占位符（由 hyprland.nix replaceStrings 注入）：
--   @HYPR_TOGGLE@   -> hypr-toggle 脚本绝对路径
--   @SWITCHER@      -> Alt+Tab 切换器二进制（hyprshell，旧 hyprswitch 已改名）
--   @EXTRA_EXEC_ONCE@ -> 其他单元（quickshell）注入的自启命令
-- =============================================================================

-- ── 终端 / 程序 ─────────────────────────────────────────
local terminal = "ghostty"   -- 用户实际终端（非 kitty）

-- ── 显示器 ─────────────────────────────────────────────
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- ── 自启（exec-once）───────────────────────────────────
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
@EXTRA_EXEC_ONCE@
end)

-- ── 环境变量 ───────────────────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ── 常规 / 装饰 ────────────────────────────────────────
hl.config({
    general = {
        gaps_in      = 2,
        gaps_out     = 2,
        border_size  = 2,
        col = {
            active_border   = "rgba(f5a962ff)",
            inactive_border = "rgba(595959aa)",
        },
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        shadow = {
            enabled      = true,
            range        = 12,
            offset       = "3 3",
            render_power = 3,
            color        = 0x00000044,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },
})

-- ── 输入 ───────────────────────────────────────────────
hl.config({
    input = {
        kb_layout  = "us",
        follow_mouse = 1,
    },
})

-- ── 键位绑定 ───────────────────────────────────────────
local mainMod = "SUPER"

-- 应用启动
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("neovide"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qutebrowser"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("ghostty"))

-- 截图
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("flameshot gui || grim -g \"$(slurp)\" - | swappy -f -"))
-- 电源/退出
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("wlogout"))
-- 应用启动器（Walker）——按 SUPER+SPACE 唤起
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("gapplication launch dev.benz.walker"))

-- 工作区切换 / 移动窗口到工作区
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- 焦点移动 + 移动窗口（Vim 键位 h/j/k/l，迭代绑定）
local vim_dir = { { "h", "left" }, { "l", "right" }, { "k", "up" }, { "j", "down" } }
for _, d in ipairs(vim_dir) do
    local key, direction = d[1], d[2]
    hl.bind(mainMod .. " + " .. key,                    hl.dsp.focus({ direction = direction }))
    hl.bind(mainMod .. " + SHIFT + " .. key,            hl.dsp.window.move({ direction = direction }))
end

-- ── 动画禁用（2026-08-22）──────────────────────────────
-- 正确 API 是独立 hl.animation({leaf=...})，非 hl.config({animations=...})。
-- leaf 全集：global/border/windows/windowsIn/Out/fade/fadeIn/Out/
--            layers/layersIn/Out/fadeLayersIn/Out/workspaces/workspacesIn/Out/zoomFactor
-- 1) 禁工作区切换动画（慢、费眼）
hl.animation({ leaf = "workspaces",    enabled = false })
hl.animation({ leaf = "workspacesIn",  enabled = false })
hl.animation({ leaf = "workspacesOut", enabled = false })

-- 2) 禁窗口淡入淡出（窗口 alpha 渐变）
hl.animation({ leaf = "fade",   enabled = false })
hl.animation({ leaf = "fadeIn", enabled = false })
hl.animation({ leaf = "fadeOut", enabled = false })

-- ── 实验性模块（热编辑，无需 switch）────────────────────
-- 编辑 ~/.config/hypr/experimental.lua 后 `hyprctl reload` 即生效。
-- pcall 保护：实验文件缺省/报错时静默忽略，不影响主配置。
pcall(require, "experimental")
