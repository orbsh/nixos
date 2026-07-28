{ config, pkgs, lib, user, ... }:

let
  cfg = config.wayland.windowManager.hyprland;

  # 1. 智能窗口切换脚本包 (严格符合 PEP 8 每行 < 79 字符，双空行规范)
  hypr-toggle-pkg = pkgs.writers.writePython3Bin "hypr-toggle" {
    libraries = [ pkgs.python3Packages.pyyaml ];
  } ''
    import json
    import subprocess
    import yaml
    import sys
    import re
    import os

    CONFIG_PATH = os.path.expanduser("~/.config/hypr/apps.yaml")
    FALLBACK_CONFIG_PATH = "/etc/hypr/apps.yaml"


    def load_config():
        path = (
            CONFIG_PATH
            if os.path.exists(CONFIG_PATH)
            else FALLBACK_CONFIG_PATH
        )
        if not os.path.exists(path):
            sys.exit(1)
        with open(path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)


    def get_hypr_clients():
        try:
            cmd = ["hyprctl", "clients", "-j"]
            return json.loads(subprocess.check_output(cmd))
        except Exception:
            return []


    def get_active_window():
        try:
            cmd = ["hyprctl", "activewindow", "-j"]
            return json.loads(subprocess.check_output(cmd))
        except Exception:
            return {}


    def match_filter(client, filters):
        for f in filters:
            tokens = re.split(r'\s+', f.strip())
            negate = False
            if tokens[0] == 'not':
                negate = True
                tokens = tokens[1:]
            if len(tokens) < 3:
                continue
            field, op, value = tokens[0], tokens[1], tokens[2]
            if field == "app_id":
                field = "class"
            val = client.get(field, "")
            if val is None:
                val = ""
            val = str(val)

            if op == '==':
                result = val == value
            elif op == '!=':
                result = val != value
            elif op == '=~':
                result = bool(re.search(value, val, re.IGNORECASE))
            elif op == 'starts-with':
                result = val.startswith(value)
            else:
                result = False

            if negate:
                result = not result
            if not result:
                return False
        return True


    def toggle_app(key_num):
        config = load_config()
        rule = None
        for r in config.get('apps', {}).get('rules', []):
            keys = r.get('keys')
            if isinstance(keys, list):
                if keys[0] <= key_num <= keys[1]:
                    rule = r
                    break
            elif keys == key_num:
                rule = r
                break
        if not rule:
            return

        clients = get_hypr_clients()
        matched_clients = [
            c for c in clients
            if match_filter(c, rule.get('filter', []))
        ]
        active = get_active_window()
        active_addr = active.get("address", "")

        if not matched_clients:
            cmd = rule.get('cmd')
            if cmd and isinstance(cmd, list) and len(cmd) > 0:
                subprocess.Popen(cmd)
            elif cmd and isinstance(cmd, str) and cmd.strip():
                subprocess.Popen(cmd, shell=True)
        else:
            matched_addrs = [
                c.get('address') for c in matched_clients
                if c.get('address')
            ]
            if not matched_addrs:
                return
            if active_addr in matched_addrs:
                current_index = matched_addrs.index(active_addr)
                next_index = (current_index + 1) % len(matched_addrs)
                target_addr = matched_addrs[next_index]
            else:
                target_addr = matched_addrs[0]

            run_cmd = [
                "hyprctl", "dispatch", "focuswindow",
                f"address:{target_addr}"
            ]
            subprocess.run(run_cmd, check=False)


    if __name__ == "__main__":
        if len(sys.argv) > 1:
            try:
                toggle_app(int(sys.argv[1]))
            except ValueError:
                sys.exit(1)
  '';

  # 2. 自动检测系统中实际集成的包名（兼容新老命名 hyprshell / hyprswitch）
  # 优先采用新版标准的 hyprshell，若不存在则回退至 hyprswitch
  switcher-pkg = if builtins.hasAttr "hyprshell" pkgs then pkgs.hyprshell else pkgs.hyprswitch;
  switcher-bin = if builtins.hasAttr "hyprshell" pkgs then "hyprshell" else "hyprswitch";

in {
  options.wayland.windowManager.hyprland.enable = lib.mkEnableOption "Hyprland 桌面环境（含完整辅助工具链）";

  config = lib.mkIf cfg.enable {
    programs.hyprland.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "hyprland";
    };

    environment.systemPackages = with pkgs; [
      wofi mako
      grim slurp swappy
      hyprpaper cliphist
      wlogout swaylock-effects
      playerctl networkmanagerapplet pavucontrol jq
      hypr-toggle-pkg     # 注入 F1-F12 脚本
      switcher-pkg        # 🌟 自动注入 Alt+Tab 高级切换器包
    ];

    home-manager.users.${user} = {
      # ── 输入法环境变量 ──────────────────────────────────
      home.sessionVariables = {
        XMODIFIERS = "@im=fcitx";
        GTK_IM_MODULE = "fcitx";
        QT_IM_MODULE = "fcitx";
      };

      xdg.configFile."hypr/hyprland.conf".text = ''
        # ── 1. 自动启动守护进程 (Exec-once) ───────────────────
        exec-once = mako
        exec-once = hyprpaper
        exec-once = nm-applet --indicator
        exec-once = fcitx5 -d

        # 自启 Alt+Tab 后台服务 (按照最近聚焦 MRU 机制排序)
        exec-once = ${switcher-bin} init --show-title --init-sort-type "recently-focused" &

        # 剪贴板历史自启
        exec-once = wl-paste --type text --watch cliphist store
        exec-once = wl-paste --type image --watch cliphist store

        # ── 2. 基础窗口与显示器配置 ──────────────────────────
        monitor=,preferred,auto,2

        # ── 2.0 键盘配置 ────────────────────────────────────
        input {
            kb_layout = us
            kb_options = ctrl:swapcaps
        }

        # ── 2.1 通用布局 ──────────────────────────────────
        general {
            gaps_in = 2
            gaps_out = 2
            border_size = 2
            col.active_border = rgba(f5a962ff)
            col.inactive_border = rgba(595959aa)
        }

        # ── 2.2 装饰：圆角 + 阴影 ────────────────────────────
        decoration {
            rounding = 10
            shadow {
                enabled = true
                range = 12
                offset = 3 3
                render_power = 3
                color = rgba(00000044)
            }
        }

        # ── 3. F1-F12 智能快捷键绑定 ──────────────────────────
        bind = , F1,  exec, hypr-toggle 1
        bind = , F2,  exec, hypr-toggle 2
        bind = , F3,  exec, hypr-toggle 3
        bind = , F4,  exec, hypr-toggle 4
        bind = , F5,  exec, hypr-toggle 5
        bind = , F6,  exec, hypr-toggle 6
        bind = , F7,  exec, hypr-toggle 7
        bind = , F8,  exec, hypr-toggle 8
        bind = , F9,  exec, hypr-toggle 9
        bind = , F10, exec, hypr-toggle 10
        bind = , F11, exec, hypr-toggle 11
        bind = , F12, exec, hypr-toggle 12

        # ── 4. 🌟 完美的 Alt+Tab 现代切换状态机绑定 ───────────────
        # 按下 Alt+Tab：呼出切换菜单，并在窗口列表内前向循环
        bind = ALT, TAB, exec, ${switcher-bin} gui --mod-key alt --key tab

        # 按下 Alt+Shift+Tab：在菜单内反向循环窗口
        bind = ALT SHIFT, TAB, exec, ${switcher-bin} gui --mod-key alt --key tab --reverse-key shift

        # 核心释放判定：松开左 Alt 键瞬间，瞬间跳转到选中的窗口并完全关闭 GUI
        bindr = ALT, ALT_L, exec, ${switcher-bin} close

        # ── 5. 其他基础功能快捷键 ───────────────────────────
        bind = SUPER, q, exec, flameshot gui || grim -g "$(slurp)" - | swappy -f -

        # ── 7. 电源/退出菜单 ───────────────────────────────────
        bind = SUPER SHIFT, q, exec, wlogout

        # ── 8. 应用启动器 ──────────────────────────────────────
        bind = SUPER, SPACE, exec, wofi --show drun

        # ── 9. 工作区切换 ──────────────────────────────────────
        bind = SUPER, 1, workspace, 1
        bind = SUPER, 2, workspace, 2
        bind = SUPER, 3, workspace, 3
        bind = SUPER, 4, workspace, 4
        bind = SUPER, 5, workspace, 5
        bind = SUPER, 6, workspace, 6
        bind = SUPER, 7, workspace, 7
        bind = SUPER, 8, workspace, 8
        bind = SUPER, 9, workspace, 9
        bind = SUPER, 0, workspace, 10

        bind = SUPER SHIFT, 1, movetoworkspace, 1
        bind = SUPER SHIFT, 2, movetoworkspace, 2
        bind = SUPER SHIFT, 3, movetoworkspace, 3
        bind = SUPER SHIFT, 4, movetoworkspace, 4
        bind = SUPER SHIFT, 5, movetoworkspace, 5
        bind = SUPER SHIFT, 6, movetoworkspace, 6
        bind = SUPER SHIFT, 7, movetoworkspace, 7
        bind = SUPER SHIFT, 8, movetoworkspace, 8
        bind = SUPER SHIFT, 9, movetoworkspace, 9
        bind = SUPER SHIFT, 0, movetoworkspace, 10

        # ── 10. 窗口焦点切换（方向键） ─────────────────────────
        bind = SUPER, left, movefocus, l
        bind = SUPER, right, movefocus, r
        bind = SUPER, up, movefocus, u
        bind = SUPER, down, movefocus, d

        # ── 11. 窗口位置移动（方向键） ─────────────────────────
        bind = SUPER SHIFT, left, movewindow, l
        bind = SUPER SHIFT, right, movewindow, r
        bind = SUPER SHIFT, up, movewindow, u
        bind = SUPER SHIFT, down, movewindow, d

        # ─ 6. 窗口规则 ──────────────────────────────────
        windowrule = match:class ^(mpv)$, float on, size 1280 720, center on
      '';

      xdg.configFile."hypr/apps.yaml".source = ../assets/hypr/apps.yaml;

      # ── Mako 通知配置 ──────────────────────────────────────
      xdg.configFile."mako/config".text = ''
        border-radius=10
        padding=10
      '';
    };
  };
}
