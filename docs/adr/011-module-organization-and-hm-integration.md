# ADR-011: 模块组织与 Home Manager 集成策略

**日期**: 2026-06-10
**状态**: 已采纳

### 问题

1. `modules/home/` 目录包含桌面 HM 配置（terminals、xdg）和通用 HM 配置（shell、editors、git），但桌面配置理应属于 `desktop/` 域
2. `core.nix` 隐式导入 `home.nix`，presets 无法选择性加载
3. `nixos-builder.nix` 的 `baseModules` 硬编码了 `core.nix`，builder 不再是纯构建工具
4. 部分模块（如 `hyprland.nix`）同时需要 NixOS 层和 HM 层配置，硬拆分会导致共享变量传递复杂化

### 备选方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| **A. 保留 `modules/home/` 独立目录** | HM 配置集中一处 | 桌面 HM 配置（terminals、xdg）与桌面域分离，内聚性差 |
| **B. 全部在 builder 中加载** | presets 简洁 | builder 有状态，不灵活；无法为特殊场景（ISO）定制 |
| **C. 混合模块拆成 system + hm 两个文件** | 严格分层 | 共享变量需参数传递；相关配置分散，难以维护 |
| **D. HM 按归属域分散 + presets 显式导入 + 混合模块保持内聚** | 灵活、内聚、职责清晰 | presets 需显式写两行 import |

### 决策

采用 **方案 D**，具体包含四项子决策：

#### 1. HM 模块按归属域组织

| 归属 | 位置 | 内容 |
|------|------|------|
| 通用（所有 host） | `system/units/home-{base,shell,editors,git}.nix` | stateVersion、nushell、helix/neovim、git |
| 桌面专属 | `desktop/home.nix` → `desktop/units/home-{terminals,xdg}.nix` | ghostty/alacritty/zellij、mimeApps/userDirs |

`modules/home/` 目录删除。

#### 2. `core.nix` 与 `home.nix` 解耦

```nix
# system/core.nix — 纯系统模块
imports = [ ./units/sys.nix ./units/base.nix ... ];

# system/home.nix — HM 聚合入口（独立）
imports = [ ./units/home-base.nix ./units/home-shell.nix ... ];
```

#### 3. Presets 显式导入

```nix
# presets/workstation-base.nix
imports = [
  ../system/core.nix     # 系统模块
  ../system/home.nix     # 通用 HM
  ../desktop/full.nix    # 桌面系统模块
  ../desktop/home.nix    # 桌面 HM
  ...
];
```

`nixos-builder.nix` 的 `baseModules` 只保留 disko 和 HM 集成配置，不导入业务模块。

#### 4. 跨层模块保持混合

当一个模块同时需要 NixOS 层和 HM 层配置，且共享变量时，保持在同一文件：

```nix
# desktop/units/hyprland.nix — 混合模块（合理）
{
  # NixOS 层
  programs.hyprland.enable = true;
  environment.systemPackages = [ switcher-pkg ];

  # HM 层（引用同一个 let 变量）
  home-manager.users.${user} = {
    xdg.configFile."hypr/hyprland.conf".text = ''
      exec-once = ${switcher-bin} init ...
    '';
  };
}
```

**组件归属判断**：当组件理论上可被多个项目依赖但实际只与特定生态配合时，按实际使用场景归属。例如 pop-launcher 虽可配合 pop-shell/cosmic-launcher/onagre，但实际只与 cosmic-launcher 使用，因此其插件配置合并到 `cosmic.nix`。

### 理由

1. **归属内聚** — terminals/xdg 是桌面专属，放在 `desktop/` 比放在独立 `home/` 更合理
2. **策略与机制分离** — builder 是机制（how to build），presets 是策略（what to include）
3. **显式优于隐式** — presets 声明依赖，不需要看 `core.nix` 才知道加载了什么
4. **混合模块实用** — 强拆分会导致变量传递复杂、相关配置分散

### 模块分类规则

| 模块类型 | 模式 | 示例 |
|----------|------|------|
| 纯系统 | 无 `home-manager.users` 块 | `sys.nix`、`nix.nix`、`network.nix` |
| 纯 HM | 无 NixOS 层配置，包裹在 `home-manager.users.${user}` 中 | `home-shell.nix`、`home-git.nix` |
| 跨层混合 | NixOS + HM 共享变量 | `hyprland.nix`、`eww.nix`、`rime.nix` |

### 后果

- `modules/home/` 目录删除，文件迁移至 `system/units/` 和 `desktop/units/`
- 所有 preset 需显式导入 `core.nix` + `home.nix`（及桌面 preset 的 `desktop/home.nix`）
- 新增 preset 时需记得导入基础模块（可通过代码审查缓解）
- 跨层模块（hyprland、eww、rime）保持不变，无需拆分
