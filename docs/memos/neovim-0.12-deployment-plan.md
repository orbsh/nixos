# NixOS 下 Neovim 0.12 "软硬分离"标准配置模板

> **状态**: 初始框架（待补充）
> **创建时间**: 2026-06-12
> **目标**: 实现 Neovim 0.12 + Neovide 的终极部署方案，彻底告别 Mason 和配置污染

---

## 〇、旧配置审计（~/Configuration/nvim）

### 0.1 插件清单（共 59 个，按 lazy-lock.json）

| # | 插件 | 类别 | 当前状态 | 0.12 迁移建议 |
|---|------|------|----------|--------------|
| 1 | **blink.cmp** | 补全 | ✅ 启用 | ✅ 保留。轻量 Rust 补全，符合原生方向 |
| 2 | **nvim-cmp** | 补全 | ❌ 禁用 | 🗑 删除。与 blink.cmp 重复，0.12 原生补全已可替代 |
| 3 | **cmp-nvim-lsp / cmp-buffer / cmp-path / cmp-cmdline / cmp_luasnip** | 补全源 | ❌ 禁用 | 🗑 删除。随 nvim-cmp 一起移除 |
| 4 | **LuaSnip + friendly-snippets** | 代码片段 | ✅ 启用 | ⚠️ 保留但降级。blink.cmp 自带 snippet 支持，LuaSnip 仅作 fallback |
| 5 | **nvim-lspconfig** | LSP 连接 | ✅ 启用 | ✅ 保留。0.12 的 `vim.lsp.enable{}` 仍需 lspconfig 做 config bridge |
| 6 | **neo-tree.nvim** | 文件树 | ✅ 启用 | ✅ 保留，需脱水配置（去图标、去连线、tab-scoped） |
| 7 | **nvim-tree.lua** | 文件树 | ❌ 禁用 | 🗑 删除。已被 neo-tree 替代 |
| 8 | **lualine.nvim** | 状态栏 | ✅ 启用 | ✅ 保留。用户偏好保留，tabline 集成 aerial + overseer |
| 9 | **aerial.nvim** | 符号大纲 | ✅ 启用 | ⚠️ 可选保留。作为 tabline 符号源有用，但 UI 展示与极简冲突 |
| 10 | **nvim-treesitter** | 语法解析 | ✅ 启用 | ✅ 保留。0.12 内置 treesitter，但 parser 管理仍需插件 |
| 11 | **nvim-treesitter-textobjects** | TS 文本对象 | ✅ 启用 | ✅ 保留。`ai`/`ii` 等操作仍依赖此 |
| 12 | **flash.nvim** | 跳转 | ✅ 启用 | ✅ 保留。标签跳转，比 hop 更现代 |
| 13 | **hop.nvim** | 跳转 | ✅ 启用 | 🗑 删除。与 flash.nvim 功能重叠，保留一个 |
| 14 | **gitsigns.nvim** | Git 标记 | ✅ 启用 | ✅ 保留。轻量 git gutter + hunk 操作 |
| 15 | **neogit** | Git 界面 | ✅ 启用 | ✅ 保留。Magit 式 Git 操作界面，集成 diffview |
| 16 | **diffview.nvim** | Git Diff | ✅ 启用 | ✅ 保留。neogit 集成依赖，diff 审计核心工具 |
| 17 | **telescope.nvim** | 模糊搜索 | ✅ 启用 | ✅ 保留。文件/内容搜索核心 |
| 18 | **telescope-tele-tabby.nvim** | Tab 列表 | ✅ 启用 | ⚠️ 可选。tabline 自定义后可替代 |
| 19 | **telescope-emoji.nvim** | Emoji 搜索 | ✅ 启用 | 🗑 删除。审计场景不需要 |
| 20 | **telescope-env.nvim** | 环境变量 | ✅ 启用 | 🗑 删除。极少使用 |
| 21 | **nvim-spectre** | 搜索替换 | ✅ 启用 | ✅ 保留。项目级搜索替换 |
| 22 | **vim-fugitive** | Git 命令 | ✅ 启用 | 🗑 删除。neogit 已覆盖 Git 操作需求 |
| 23 | **nvim-surround** | 环绕编辑 | ✅ 启用 | ✅ 保留。`ys`/`cs`/`ds` 高效 |
| 24 | **Comment.nvim** | 注释 | ✅ 启用 | ✅ 保留。`gcc`/`gc` 标准操作 |
| 25 | **vim-visual-multi** | 多光标 | ✅ 启用 | ⚠️ 可选。审计场景少用，但编辑时方便 |
| 26 | **vim-easy-align** | 对齐 | ✅ 启用 | ✅ 保留。`ga` 对齐，轻量实用 |
| 27 | **ultimate-autopair.nvim** | 自动配对 | ✅ 启用 | ⚠️ 可选。与 nvim-autopairs 重复，保留一个 |
| 28 | **nvim-autopairs** | 自动配对 | ❌ 禁用 | 🗑 删除。已被 ultimate-autopair 替代 |
| 29 | **rainbow_parentheses.vim** | 彩虹括号 | ✅ 启用 | ⚠️ 迁移到 p00f/rainbow-delimiters.nvim（TS-based） |
| 30 | **whitespace.nvim** | 空白标记 | ✅ 启用 | ✅ 保留。轻量，标记+清除尾随空白 |
| 31 | **resession.nvim** | 会话管理 | ✅ 启用 | ✅ 保留。轻量会话保存/恢复 |
| 32 | **possession.nvim** | 会话管理 | ❌ 禁用 | 🗑 删除。已被 resession 替代 |
| 33 | **auto-save.nvim** | 自动保存 | ✅ 启用 | ✅ 保留。条件保存逻辑合理 |
| 34 | **nvim-early-retirement** | Buffer 回收 | ✅ 启用 | ✅ 保留。自动关闭闲置 buffer |
| 35 | **overseer.nvim** | 任务运行 | ✅ 启用 | 🗑 删除。0.12 内置 `:terminal` 替代 |
| 36 | **nvim-dap + nvim-dap-ui** | 调试器 | ✅ 启用 | ⚠️ 可选。审计场景少用调试，但保留能力 |
| 37 | **trouble.nvim** | 诊断列表 | ✅ 启用 | ⚠️ 可选。quickfix/loclist 原生够用 |
| 38 | **todo-comments.nvim** | TODO 标记 | ✅ 启用 | ⚠️ 可选。审计场景有用（标记待审项） |
| 39 | **noice.nvim** | 消息 UI | ✅ 启用 | 🗑 删除。0.12 `ui2` 已原生解决 "Press ENTER" 问题 |
| 40 | **dressing.nvim** | UI 美化 | ✅ 启用 | 🗑 删除。0.12 原生 `vim.ui.select` 已够用 |
| 41 | **nvim-notify** | 通知 | ✅ 启用 | 🗑 删除。伪 GUI 弹窗，违反视觉纯净 |
| 42 | **nui.nvim** | UI 库 | ✅ 启用 | ⚠️ 仅当 neo-tree 依赖时保留 |
| 43 | **nvim-colorizer.lua** | 颜色预览 | ✅ 启用 | 🗑 删除。审计场景不需要 |
| 44 | **nvim-web-devicons** | 文件图标 | ✅ 启用 | 🗑 删除。纯文本原则，不需要图标 |
| 45 | **nerdy.nvim** | Nerd 图标搜索 | ✅ 启用 | 🗑 删除。违反纯文本原则 |
| 46 | **marks.nvim** | 标记管理 | ✅ 启用 | ✅ 保留。增强原生 mark 功能 |
| 47 | **registers.nvim** | 寄存器预览 | ✅ 启用 | ✅ 保留。审计时频繁粘贴需要 |
| 48 | **nvim-window-picker** | 窗口选择 | ✅ 启用 | ✅ 保留。分屏跳转 |
| 49 | **winshift.nvim** | 窗口移动 | ✅ 启用 | ✅ 保留。窗口重排 |
| 50 | **plenary.nvim** | 工具库 | ✅ 启用 | ✅ 保留。多插件依赖 |
| 51 | **popup.nvim** | 弹出窗口 | ✅ 启用 | ⚠️ 仅 telescope 依赖时保留 |
| 52 | **nvim-nio** | 异步 IO | ✅ 启用 | ⚠️ 仅 dap 依赖时保留 |
| 53 | **null-ls.nvim** | LSP 非语言 | ✅ 启用 | 🗑 删除。已废弃，迁移到 none-ls.nvim 或直接用 formatter |
| 54 | **schemastore.nvim** | JSON Schema | ✅ 启用 | ✅ 保留。为 yaml/json LSP 提供 schema |
| 55 | **iswap.nvim** | TS 参数交换 | ✅ 启用 | ⚠️ 可选。Treesitter 操作，编辑时有用 |
| 56 | **vim-dadbod + dadbod-ui + dadbod-completion** | SQL 数据库 | ✅ 启用 | ✅ 保留。SQL 审计核心工具 |
| 57 | **moonbit.nvim** | MoonBit 语言 | ✅ 启用 | 🗑 删除。不需要 |
| 58 | **vim-helm** | Helm 模板 | ✅ 启用 | ✅ 保留。K8s 审计需要 |
| 59 | **typst.vim** | Typst 排版 | ✅ 启用 | 🗑 删除。不需要 |

**其他 manifest 中出现的插件（未在 lock 中）：**

| 插件 | 状态 | 说明 |
|------|------|------|
| better-escape.nvim | 条件启用 | 双键 Esc，环境变量控制 |
| which-key.nvim | ❌ 禁用 | 键位提示 |
| vim-rsi | ❌ 禁用 | readline 风格键位 |
| neophyte | ❌ 禁用 | 特殊字符显示 |
| neorg / orgmode | ❌ 禁用 | 笔记系统 |
| gruvbox.nvim | ❌ 禁用 | 主题（使用 gruvbox-material） |
| melange-nvim | 备用主题 | 未激活 |
| nvim-hlslens | ❌ 禁用 | 搜索高亮 |
| stabilize.nvim | ❌ 禁用 | 滚动稳定 |
| neoscroll.nvim | ❌ 禁用 | 平滑滚动 |
| nvim-osc52 | ❌ 禁用 | 剪贴板 |
| nvim-unception / flatten.nvim | ❌ 禁用 | 嵌套 nvim 处理 |
| instant.nvim | ✅ 启用 | 协作编辑 → 🗑 删除 |
| scratch.nvim | ✅ 启用 | 草稿本 |
| sniprun | ❌ 禁用 | 代码运行 |
| rest.nvim | ❌ 禁用 | HTTP 请求 |
| nvim-luapad | ✅ 启用 | Lua 交互 |
| nvimesweeper | ✅ 启用 | 扫雷游戏 → 🗑 删除 |
| vim-speeddating / dial.nvim | ❌ 禁用 | 数字递增 |
| term-edit.nvim | ❌ 禁用 | 终端编辑 |
| nvim-taberm | ✅ 启用 | 终端管理（替代 Zellij） |
| vim-mundo | ❌ 禁用 | 撤销树 |
| nvim-peekup / yanky.nvim | ❌ 禁用 | 寄存器增强 |
| codecompanion.nvim | ❌ 禁用 | AI 辅助 |

### 0.2 自定义配置摘要

**架构特征：**
- **分级加载系统**：`vim.g.nvim_level` 环境变量控制功能层级（1=最小/远程，2=标准，3=完整/Neovide）
- **模块化 manifest**：插件按类别分文件（base/ui/vcs/motion/component/dev/task/term/lang/ai/experiment/other/game/fixme）
- **统一配置加载**：`lazy_helper.settings` 函数从 `lua/settings/` 目录加载对应配置
- **键位抽象**：`setup.mod()` 函数将 `C-`/`M-`/`M-S-` 前缀抽象化，通过 `NVIM_PREFER_ALT` 环境变量切换
- **箭头键重映射**：`NVIM_ARROW` 环境变量支持 vim 风格方向键（hjkl→jkl;）
- **条件 Git**：`vim.g.has_git` 检测 git 可用性，无 git 环境自动跳过 git 相关功能

**LSP 配置（lua/settings/lsp/base.lua）：**
- 使用 0.12 原生 `vim.lsp.enable{}` 语法
- 启用语言：nushell, pyrefly, hls, ts_ls, gopls, tinymist
- 条件启用：sql (level≥3)

**Neo-tree 配置（lua/settings/neotree.lua）：**
- 已部分脱水：`folder_closed="+"`, `folder_open="-"`, `default="*"`
- Git 状态符号部分已清空（added="", modified=""）
- 仍有残留图标：deleted="✖", untracked="", ignored="", unstaged="", staged="", conflict=""
- 缩进连线未明确关闭（`with_markers` 未设置）
- 未配置 `cwd_target.sidebar = "tab"`（Tab 作用域隔离）

**Lualine 配置（lua/settings/lualine.lua）：**
- 使用 gruvbox-material 主题
- Tabline 集成 aerial 符号 + overseer 任务
- 有 `NVIM_LUALINE_PLAIN` 环境变量控制分隔符（纯文本模式）
- DirChanged autocmd 自动命名 Tab

**Blink.cmp 配置（lua/settings/blink_cmp.lua）：**
- 使用 `enter` 预设键位
- 支持 Alt+数字 直接选择第 N 项
- cmdline 补全已启用
- 已配置 LSP capabilities 注入

**Overseer 配置（lua/settings/overseer.lua）：**
- 自定义 "run script" 模板支持多语言直接运行（python/go/rust/haskell/julia/scheme/ruby/nu/sh/bash）
- 任务面板在右侧

**Auto-save 配置（lua/settings/auto-save.lua）：**
- 条件排除：非普通文件、/tmp/、gitcommit、不可修改 buffer

### 0.3 键位汇总与冲突分析

#### LSP 键位（`;` 前缀系列）

| 键位 | 功能 | 模式 |
|------|------|------|
| `gd` | 跳转声明 | n |
| `;d` | 跳转定义 | n |
| `;x` | 查找引用 | n |
| `K` | 悬停文档 | n |
| `gi` | 跳转实现 | n |
| `;k` | 签名帮助 | n |
| `;r` | 重命名 | n |
| `;a` | 代码操作 | n |
| `;f` | 格式化 | n |
| `;D` | 类型定义 | n |
| `;p` | 前一诊断 | n |
| `;n` | 后一诊断 | n |
| `;l` | 设置 loclist | n |
| `;o` | 浮动窗口 | n |
| `;wa/wr/wl` | 工作区管理 | n |

#### Git 键位（`g` 前缀 + `<leader>g` 系列）

| 键位 | 插件 | 功能 |
|------|------|------|
| `g[` / `g]` | gitsigns | 上/下一 hunk |
| `gp` | gitsigns | 预览 hunk |
| `gh` / `gH` | gitsigns | stage/reset hunk |
| `gX` | gitsigns | undo stage |
| `gs` / `gS` | gitsigns | stage/reset buffer |
| `gl` | gitsigns | blame line |
| `gL` | gitsigns | toggle blame |
| `gm` / `gM` | gitsigns | diffthis |
| `gP` | gitsigns | toggle deleted |
| `ih` | gitsigns | select hunk (o/x) |
| `<leader>gd` | diffview | DiffviewOpen |
| `<leader>gf` | diffview | FileHistory % |
| `<leader>gh` | diffview | FileHistory |
| `<leader>gx` | diffview | DiffviewClose |
| `<leader>gg` | neogit | 打开 Neogit |

#### Telescope 键位（`<leader>` 系列）

| 键位 | 功能 |
|------|------|
| `<leader>p` | pickers 列表 |
| `<leader>y` | LSP 文档符号 |
| `<leader>a` | marks |
| `<leader>z` | registers |
| `<leader>d` | oldfiles |
| `<leader>f` | find_files |
| `<leader>r` | live_grep |
| `<leader>T` | tabs |
| `<leader>F` | git_files |
| `<leader>gc` | git_commits |
| `<leader>gB` | git_branches |
| `<leader>gS` | git_status |
| `<leader>go` | git_bcommits |
| `<leader>b` | buffers |
| `<leader>[` | builtin |
| `<leader>]` | help_tags |
| `<leader>N` | notify |

#### Trouble 键位

| 键位 | 功能 |
|------|------|
| `<leader>gw` | diagnostics |
| `<leader>gs` | symbols |
| `<leader>gl` | loclist |
| `<leader>gq` | qflist |
| `<leader>gr` | lsp refs |
| `<leader>ga` | TodoTelescope |
| `<leader>gt` | TodoTrouble |

#### 其他键位

| 键位 | 插件 | 功能 |
|------|------|------|
| `<leader>e` | neo-tree | 文件树 |
| `<leader>ww` | window-picker | 窗口选择 |
| `<leader>ws/wx` | winshift | 窗口交换/移动 |
| `<leader>SS/SL/SD` | resession | 保存/加载/删除会话 |
| `<leader>s` | aerial | Telescope 符号搜索 |
| `<C-s>` | aerial | 切换符号面板 |
| `;s` | spectre | 搜索替换 |
| `ga` | easy-align | 对齐 |
| `gw` | whitespace | 清除尾随空白 |
| `s/S` | flash.nvim | 标签跳转 / TS 跳转 |
| `r/R` | flash.nvim | 远程跳转 / TS 搜索（o/x） |
| `<leader><leader>` | hop.nvim | 词跳转 |
| `<leader>;` | hop.nvim | 行跳转 |
| `<M-q>` | window-picker | 窗口快选（n/x/i/t） |
| `<M-[/]>` | taberm | 终端切换/分屏 |
| `<M-y>` | taberm | 终端粘贴 |
| `<M-s>` | LuaSnip | on-the-fly snippet |
| `<M-t>` | overseer | 切换任务面板 |
| `<leader>or/oo/ob/ot/oq` | overseer | 任务操作系列 |
| `,b/l/B/L/c/s/i/o/r/X/C/x/v` | dap | 调试器全系列 |

#### 🔴 冲突汇总

| 键位 | 冲突方 A | 冲突方 B | 解决建议 |
|------|----------|----------|----------|
| `<leader>gl` | gitsigns: blame_line | trouble: loclist | 保留 gitsigns（审计核心），trouble 改用 `<leader>tl` |
| `<leader>gs` | gitsigns: stage_buffer | trouble: symbols | 保留 gitsigns，trouble 改用 `<leader>ts` |
| `<leader>gS` | gitsigns: reset_buffer | telescope: git_status | 统一归属，telescope 改为 `<leader>gss` 或 gitsigns 改为 `<leader>gR` |
| `s` | flash.nvim: search | Vim 原生 substitute | flash 覆盖原生 `s`，可接受但需注意 |
| `S` | flash.nvim: treesitter | Vim 原生 S (substitute line) | 同上，丢失原生功能 |

### 0.4 迁移建议总结

**第一优先级：立即删除（违反 0.12 架构原则）**
- nvim-cmp 全家桶 → 0.12 原生补全 / blink.cmp
- noice.nvim → 0.12 ui2 原生消息
- dressing.nvim → 0.12 原生 vim.ui
- nvim-notify → 违反视觉纯净
- nvim-web-devicons → 纯文本原则
- nerdy.nvim → 纯文本原则
- nvim-colorizer → 审计不需要
- null-ls.nvim → 已废弃
- hop.nvim → 与 flash.nvim 重复
- nvim-tree.lua → 已被 neo-tree 替代
- possession.nvim → 已被 resession 替代
- nvim-autopairs → 已被 ultimate-autopair 替代

**第二优先级：精简（功能重叠或审计场景冗余）**
- vim-fugitive → neogit 已覆盖 Git 操作
- trouble.nvim → quickfix/loclist 原生够用
- overseer.nvim → `:terminal` 替代
- telescope-emoji / telescope-env → 极少使用
- nvim-dap + dap-ui → 审计场景少用
- instant.nvim → 协作编辑不需要
- nvimesweeper → 游戏删除
- moonbit.nvim → 不需要
- typst.vim → 不需要

**第三优先级：保留但需改造**
- neo-tree → 脱水配置（去图标、去连线、tab-scoped）
- flash.nvim → 确认 `s`/`S` 覆盖原生是否可接受
- gitsigns + trouble → 解决键位冲突
- rainbow_parentheses → 迁移到 rainbow-delimiters.nvim（TS-based）

**最终目标插件数：~25 个**（从 59 → ~25）

---

## 一、AI 系统提示词与架构规约

为了能够让你在未来的开发中，将这套硬核的 Neovim 0.12 + Neovide 架构一键喂给大语言模型（LLM/AI），让 AI 能够完美理解你的审美偏好、底层逻辑并为你精准生成不含低幼噪点的配置，以下为你整理了一份专为 AI 深度优化的系统提示词与架构规约文档（System Prompt / Context Context Doc）。

你可以直接将以下 Markdown 内容作为 Context 或 `.cursorrules` / `system_prompt` 喂给任何 AI 助手。

### Neovim 0.12 + Neovide 极简代码审计平台架构规约（For AI）

#### 📌 用户画像与核心审美（User Profile & Aesthetics）

**技术背景**：用户是拥有 10 年 Emacs、7-8 年 Neovim、2-3 年 Helix 经验的顶级开发者。精通 Rust, Lisp (Scheme), Haskell, Scala, Go, Lua (OpenResty/Redis 级别) 等二十多种语言。

**工具定位**：编辑器在此场景下已完全退化/升级为"纯粹的代码审计平台"。不承担大量增删代码工作，核心关注：项目文件导航、Git 历史追溯/变基/Diff 审计、内置终端联动、高能文本检索。

**极致审美与偏好**：
- **极度反感网红 TUI 的低幼化（Juvenile）设计**：坚决拒绝在字符终端里用 Box-drawing 字符去堆砌圆角、层级、虚假 GUI 边框、花哨 Nerd 图标。这被视为浪费屏幕空间、分散注意力的低效设计。
- **重度集成度要求**：要求 100% 的一体化（Integration）。拒绝使用 Zellij、Tmux、Yazi、Lazygit 等外部独立工具拼接，所有功能必须由 Neovim 0.12 核心（C Core PTY）分发，确保在 Neovide GUI 下享用完全统一的亚像素字体渲染与物理微动画。
- **对 Lua 的态度**：用户精通 Lua 但极度讨厌它。在 Neovim 配置中，Lua 只能作为声明式（Declarative）的键值对配置工具（类似 JSON/TOML），严禁引入复杂的 Lua 闭包、异步回调地狱或架空内核的重型 Lua 插件生态。

#### 🛠️ Neovim 0.12 核心架构原则（Neovim 0.12 Core Rules）

在为用户生成或修改 `init.lua` 时，AI 必须严格遵守以下基于 Neovim 0.12 最新特性的技术约束：

**1. 原生下沉原则（Sink to C Core）**：
- **自动补全**：禁止使用 `nvim-cmp`、`coq_nvim` 及其各种庞杂的 Lua 源（Sources）。必须且仅能使用 0.12 内置的纯 C 层异步补全：`vim.opt.autocomplete = true`。
- **包管理器**：禁止使用 `lazy.nvim` 或 `packer.nvim`。必须直接使用 0.12 原生内置的 `vim.pack` 机制进行声明式配置，并维护 `nvim-lock.json`。

**2. 视觉纯净度最大化（Max Information Density）**：
- 禁止安装 `noice.nvim`、`fidget.nvim` 等伪 GUI 弹窗。0.12 原生 `ui2` 已消除 "Press ENTER" 中断，消息直接在命令行或原生 Buffer 流中呈现。
- 必须将状态栏彻底关闭（`vim.opt.laststatus = 0`），释放 100% 屏幕空间给文本本身。
- 必须抹平分屏线颜色（`WinSeparator` 设为 `none`），让视窗物理边界消融。

**3. 标准的现代正则搜索（Very Magic Regex）**：
- 用户极其讨厌 Vim 默认的反向转义正则（如 `\(...\)`、`\|`）。
- 必须在所有键盘映射中，为 `/`、`?`、`:%s/` 等搜索/替换前置自动化注入 `\v`（Very Magic 模式），使其行为 95% 等价于 PCRE/Perl/Python 标准正则（如 `/\v(error|panic).\+`）。

#### 📐 核心三大支柱配置规约（The Three Pillars）

**1. Tab-local 级别项目隔离（One Project Per Tab）**
- 用户的核心心智模型是 "把每个 Tab 视为一个独立项目"。
- **路径锁定**：必须使用 2016 年内核引入的 `:tcd` (Tab-local Current Working Directory) 命令来硬核隔离每个标签页。禁止使用全局 `:cd` 或窗口级 `:lcd`。
- **顶部项目栏净化**：禁止使用带彩色圆角的 `bufferline`。必须通过重写 `vim.opt.tabline`，用纯文本计算并提取当前 Tab 的 `:tcd` 路径最后一级文件夹名，将其渲染为最纯粹的项目名称列表（形如 `1:rust-service 2:go-api*`）。

**2. 脱水级 Neo-tree 配置（Dehydrated Neo-tree）**
- 用户认可 Neo-tree 的操作逻辑，但极其讨厌其默认的视觉噪点。
- **配置约束**：
  - 必须将所有 icon（包括文件夹、文件、Git 状态符号）设为空字符串 `""`。Git 状态仅通过纯文本的颜色高亮（Color Hint）暗示，拒绝 `[M]`, `[U]` 等字符框。
  - 必须将树状缩进连线彻底关闭（`with_markers = false`），文件层次纯靠空格（Padding）缩进，维持像 Python/Haskell 源码一样的纯净感。
  - 必须通过 `cwd_target.sidebar = "tab"`，让 Neo-tree 实例完美属于当前的 Tab 作用域。当用户在不同 Tab（项目）间切换时，侧边栏必须微秒级自动动态刷新为对应项目的根目录。

**3. C Core 内置终端接管（PTY Buffer Takeover）**
- 彻底废除 Zellij。所有多任务流转必须通过 Neovim 内置的 `:terminal` 实现。
- **进程目录承袭**：在 0.12 架构下，因 Tab 锁定了 `:tcd`，通过 `:terminal` 唤起的新进程必须完美承袭当前项目的 CWD 路径。
- **终端 Buffer 化**：
  - 在终端模式下按 `Esc` 必须无感重置回 Normal 模式（利用映射 `[[<C-\><C-n>]]`）。
  - 退回 Normal 模式后，终端将作为一个只读的 Vim Buffer 存在。AI 必须理解用户此时可以使用刚才配置的标准正则（`\v`）对终端输出的数万行 AI 审计日志、编译日志进行凌厉的文本检索，并直接进行 `y` (yank) 复制。
  - 光标移动到日志内的特定路径（如 `src/main.rs:42`）时，支持通过原生 `gF` 键，让左侧代码视窗直接精准跳转。

#### 📋 NixOS 声明式环境架构（NixOS Pure Infrastructure）

- **软硬分离原则**：禁止使用 NixVim / NVF 这类将 Lua 配置混进 Nix 语言的反人类框架。
- **NixOS 的职责**：负责环境的 Purity（纯净性）。通过 Nix Flake 或 Home-Manager 将独立的本地纯 Lua 配置目录（`~/.config/nvim`）以符号链接形式挂载（`xdg.configFile."nvim".source`）。
- **反 Mason 约束**：由于 NixOS 缺乏标准 FHS 路径，通过 Mason 下载的二进制 LSP 会直接因找不到动态链接库而崩溃。严禁在配置中引入 Mason。所有编译器、调试器、LSP（如 `nil`, `gopls`, `rust-analyzer`, `pyright`）、`ripgrep`, `fd` 必须由 NixOS 系统层或 Home-Manager 在环境包（`environment.systemPackages`）中统一声明式注入。

#### 💡 AI 生成代码示例检查（Sanity Check For AI）

当你（AI）准备输出任何关于 Neovim 0.12 的配置时，请对照以下行为进行自检：
- 代码里是否出现了 `require('cmp')`？ → **错！** 违反 0.12 原生补全原则。
- 代码里是否出现了 `nerd_font_icons` 或线条字符？ → **错！** 违反去低幼化纯文本原则。
- 代码里是否使用了 `cd` 而不是 `tcd`？ → **错！** 违反项目隔离原则。
- 代码里是否包含 Mason 启动逻辑？ → **错！** 在 NixOS 环境下无法运行。

**使用建议**：你可以将此文档保存在你 NixOS 管理的项目配置目录下，或者在每次与 AI 讨论 Neovim 升级和插件调整时，第一步就把这段"规约"直接塞给它。

在这个架构标准下，你目前手头积攒的那几十个老插件里，有没有哪个是需要进行复杂的跨 Tab 数据通信，或者你不太确定 0.12 原生能否平替的？如果有，你可以把插件名字发出来，我们可以直接用这套"AI 规约"的严谨逻辑把它当场拆解并重构掉。

---

## 二、第一步：NixOS 硬件底座配置

### 2.1 Home-Manager 配置模板

```nix
# home.nix 或 configuration.nix
{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;  # 0.12 纯净核心
    defaultEditor = true;

    # 极简声明：让 Home-Manager 将你独立的本地配置目录以"符号链接"形式挂载
    # 这样既能纳入 Nix 的大一统管理，又保持了本地动态修改的自由度
    # 假设你的纯 Lua 配置托管在系统配置目录的 ./dotfiles/nvim
    # xdg.configFile."nvim".source = ./dotfiles/nvim;
  };

  # ⚙️ 核心审计工具链：由 NixOS 100% 保证纯净性，彻底告别 Mason！
  environment.systemPackages = [
    # 1. Neovide 顶级 GUI 驱动
    pkgs.neovide

    # 2. 你的核心审计语言 LSP / 工具链 (根据你的审计对象按需添加)
    pkgs.nil                    # Nix LSP
    pkgs.gopls                  # Go LSP
    pkgs.nodePackages.pyright   # Python LSP
    pkgs.rust-analyzer          # Rust LSP

    # 3. 基础动态工具
    pkgs.git
    pkgs.ripgrep                # 用于 Neovim 内部大范围代码检索
    pkgs.fd                     # 极其快速的文件发现，Neo-tree 依赖
  ];
}
```

### 2.2 配置要点说明

**为什么用 `pkgs.neovim-unwrapped`？**
- 纯净核心，不带任何 HM 包装的插件配置
- 避免 HM 的 `extraConfig` 污染你的独立配置

**为什么不用 Mason？**
- Mason 在 NixOS 下会遭遇动态链接地狱（glibc 版本不匹配）
- NixOS 已经全局注入了正确版本的 LSP，Mason 纯属多余
- 减少一层抽象，降低故障点

**符号链接策略**：
- 通过 `xdg.configFile."nvim".source` 将本地配置目录链接到 `~/.config/nvim`
- 保持 Nix 的大一统管理，同时允许本地动态修改

---

## 三、第二步：独立的 `~/.config/nvim/` 纯 Lua 配置

### 3.1 init.lua 完整模板

```lua
-- ~/.config/nvim/init.lua
-- Neovim 0.12 "软硬分离"标准配置

-- ═══════════════════════════════════════════════════════════
-- 1. 声明式配置 0.12 原生包管理器
-- ═══════════════════════════════════════════════════════════
vim.pack.setup({
  lockfile = vim.fn.stdpath("config") .. "/nvim-lock.json"
})

-- ═══════════════════════════════════════════════════════════
-- 2. 批量注册插件（极简主义，只装必要的）
-- ═══════════════════════════════════════════════════════════
local plugins = {
  "nvim-neo-tree/neo-tree.nvim",      -- 目录树（纯文本风格）
  "nvim-lua/plenary.nvim",            -- neo-tree 依赖
  "tpope/vim-fugitive",               -- 纯文本流 Git 审计
  "neovim/nvim-lspconfig",            -- 仅仅用来连接 Nix 注入的 LSP
}

for _, plugin in ipairs(plugins) do
  vim.pack.add(plugin)
end

-- ═══════════════════════════════════════════════════════════
-- 3. 激活 0.12 原生极简特性
-- ═══════════════════════════════════════════════════════════
vim.opt.autocomplete = true           -- 原生纯 C 异步补全，彻底丢弃 nvim-cmp
vim.opt.laststatus = 0                -- 彻底干掉状态栏，极致信息密度
vim.opt.number = true                 -- 行号（可选）
vim.opt.relativenumber = true         -- 相对行号（可选）

-- ═══════════════════════════════════════════════════════════
-- 4. 纯文本消费 NixOS 注入的全局 LSP
-- ═══════════════════════════════════════════════════════════
local lspconfig = require("lspconfig")

-- 直接启动，它们会自动寻找到 Nix 注入到 $PATH 中的二进制文件
-- 不需要 Mason，永远不会崩溃
lspconfig.rust_analyzer.setup({})
lspconfig.pyright.setup({})
lspconfig.gopls.setup({})
lspconfig.nil_ls.setup({})            -- Nix LSP

-- ═══════════════════════════════════════════════════════════
-- 5. 载入 Neo-tree 配置（纯文本风格）
-- ═══════════════════════════════════════════════════════════
-- require("config.neotree")

-- ═══════════════════════════════════════════════════════════
-- 6. 快捷键映射（极简主义）
-- ═══════════════════════════════════════════════════════════
vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Toggle Neo-tree" })
vim.keymap.set("n", "<leader>g", ":Git<CR>", { desc = "Open Fugitive" })
```

### 3.2 配置要点说明

**为什么用 `vim.pack`？**
- Neovim 0.12 原生包管理器，纯 C 实现，性能碾压 Lua 插件
- 声明式配置，lockfile 保证可重现性
- 不需要 Packer、Lazy 等第三方插件管理器

**为什么不用 nvim-cmp？**
- 0.12 已内置原生纯 C 异步补全（`vim.opt.autocomplete = true`）
- 第三方补全插件是历史包袱，性能不如原生

**为什么 `laststatus = 0`？**
- 彻底干掉状态栏，追求极致信息密度
- 所有信息都在文本矩阵中，没有视觉污染

**LSP 配置为什么这么简单？**
- NixOS 已经全局注入了正确版本的 LSP 二进制
- `lspconfig` 只是建立连接，不需要额外安装
- 自动从 `$PATH` 中找到工具，永远不会崩溃

---

## 四、待补充内容清单

### 4.1 NixOS 配置细节

- [ ] 确认 `pkgs.neovim-unwrapped` 是否已包含 0.12 版本
- [ ] 测试 `xdg.configFile."nvim".source` 的符号链接策略
- [ ] 补充 K8s 节点（无 GUI）的精简配置模板
- [ ] 补充桌面节点（有 Neovide）的完整配置模板

### 4.2 Neovim 配置细节

- [ ] Neo-tree 纯文本风格配置（拒绝圆角、图标）
- [ ] Fugitive 快捷键映射（Git 审计工作流）
- [ ] 内置 `:terminal` 分屏配置（右侧常驻 Shell）
- [ ] LSP 快捷键映射（跳转、重命名、诊断）
- [ ] Treesitter 配置（增量选择、语法高亮）

### 4.3 审计工作流

- [ ] 代码审计标准流程（打开文件 → LSP 诊断 → Git blame → 终端运行）
- [ ] 多文件对比工作流（分屏 + Fugitive diff）
- [ ] 大项目导航工作流（Neo-tree + ripgrep + fd）

### 4.4 性能优化

- [ ] 启动时间优化（延迟加载策略）
- [ ] 内存占用优化（ Treesitter 增量解析）
- [ ] Neovide 渲染优化（亚像素、动画参数）

---

## 五、实施步骤

### 阶段 1：基础设施搭建（1-2 小时）

1. 在 `~/Configuration/nixos/modules/desktop/units/neovim.nix` 中创建硬件底座配置
2. 在 K8s 节点配置中创建精简版本（无 Neovide）
3. 运行 `nh os switch` 验证安装

### 阶段 2：Lua 配置迁移（2-3 小时）

1. 备份现有 `~/.config/nvim/` 配置
2. 创建新的 `init.lua`，使用上述模板
3. 逐步迁移必要的插件配置（Neo-tree、Fugitive）
4. 测试 LSP 连接（rust-analyzer、pyright、gopls）

### 阶段 3：工作流验证（1-2 小时）

1. 在一个真实项目中测试审计工作流
2. 验证 Neo-tree 纯文本风格
3. 验证 Fugitive Git 审计
4. 验证内置终端分屏

### 阶段 4：性能调优（可选）

1. 测量启动时间（目标 < 100ms）
2. 测量内存占用（目标 < 200MB）
3. 调整 Neovide 渲染参数

---

## 六、注意事项

### 6.1 NixOS 陷阱

**陷阱 1：`neovim-unwrapped` vs `neovim`**
- `neovim` 是 HM 包装版本，可能注入额外配置
- `neovim-unwrapped` 是纯净核心，推荐使用

**陷阱 2：符号链接冲突**
- 如果 `~/.config/nvim/` 已存在，`xdg.configFile` 会报错
- 解决方案：先备份现有配置，或删除后让 NixOS 重建

**陷阱 3：LSP 路径问题**
- NixOS 注入的 LSP 在 `/run/current-system/sw/bin/`
- 确保 `$PATH` 包含该路径（NixOS 默认已包含）

### 6.2 Neovim 0.12 陷阱

**陷阱 1：`vim.pack` API 变化**
- 0.12 的 `vim.pack` 是实验性 API，可能有变化
- 建议锁定 nixpkgs 版本，避免升级导致配置失效

**陷阱 2：原生补全功能限制**
- `vim.opt.autocomplete` 功能可能不如 nvim-cmp 完善
- 如果遇到问题，可以临时回退到 nvim-cmp

**陷阱 3：插件兼容性**
- 部分老插件可能不兼容 0.12 的新 API
- 优先使用维护活跃的插件（Neo-tree、Fugitive）

---

## 七、参考资源

- [Neovim 0.12 Release Notes](https://github.com/neovim/neovim/releases/tag/v0.12.0)
- [Neovide 官方文档](https://neovide.dev/)
- [vim.pack 官方文档](https://neovim.io/doc/user/packages.html)
- [NixOS Neovim 模块](https://nixos.org/manual/nixos/stable/#opt-programs.neovim.enable)

---

## 八、版本历史

- **2026-06-12**: 添加旧配置审计（59 个插件清单、自定义配置摘要、键位冲突分析、迁移建议）
- **2026-06-12**: 添加 AI 系统提示词与架构规约文档
- **2026-06-12**: 初始框架创建
