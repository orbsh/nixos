{ config, pkgs, lib, ... }:

let
  cfg = config.wayland.windowManager.hyprland;

  # 1. 将完整的 Python 脚本通过 Nix 声明式直接构建为一个可执行包
  # 这样可以 100% 避免权限问题，并且由 Nix 全权管理依赖（pyyaml）
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
        path = CONFIG_PATH if os.path.exists(CONFIG_PATH) else FALLBACK_CONFIG_PATH
        if not os.path.exists(path):
            print(f"Error: Config file not found at {path}", file=sys.stderr)
            sys.exit(1)
        with open(path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)

    def get_hypr_clients():
        try:
            out = subprocess.check_output(["hyprctl", "clients", "-j"])
            return json.loads(out)
        except Exception:
            return []

    def get_active_window():
        try:
            out = subprocess.check_output(["hyprctl", "activewindow", "-j"])
            return json.loads(out)
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
            if val is None: val = ""
            val = str(val)

            if op == '==': result = val == value
            elif op == '!=': result = val != value
            elif op == '=~': result = bool(re.search(value, val, re.IGNORECASE))
            elif op == 'starts-with': result = val.startswith(value)
            else: result = False

            if negate: result = not result
            if not result: return False
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
        if not rule: return

        clients = get_hypr_clients()
        matched_clients = [c for c in clients if match_filter(c, rule.get('filter', []))]
        active = get_active_window()
        active_addr = active.get("address", "")

        if not matched_clients:
            cmd = rule.get('cmd')
            if cmd and isinstance(cmd, list) and len(cmd) > 0:
                subprocess.Popen(cmd)
            elif cmd and isinstance(cmd, str) and cmd.strip():
                subprocess.Popen(cmd, shell=True)
        else:
            matched_addrs = [c.get('address') for c in matched_clients if c.get('address')]
            if not matched_addrs: return
            if active_addr in matched_addrs:
                current_index = matched_addrs.index(active_addr)
                next_index = (current_index + 1) % len(matched_addrs)
                target_addr = matched_addrs[next_index]
            else:
                target_addr = matched_addrs[0]
            subprocess.run(["hyprctl", "dispatch", "focuswindow", f"address:{target_addr}"], check=False)

    if __name__ == "__main__":
        if len(sys.argv) > 1:
            try: toggle_app(int(sys.argv[1]))
            except ValueError: sys.exit(1)
  '';

in {
  options.wayland.windowManager.hyprland.enable = lib.mkEnableOption "Hyprland 桌面环境（含完整辅助工具链）";

  config = lib.mkIf cfg.enable {
    # ── Hyprland 合成器核心 ──────────────────────────────────
    programs.hyprland.enable = true;

    # ── Pipewire 音频系统 ────────────────────────────────────
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # ── XDG Desktop Portal ─────────────────────────────────
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "hyprland";
    };

    # ── 基础工具链包（包含我们用 Nix 构建的脚本包） ───────────────
    environment.systemPackages = with pkgs; [
      waybar                # 状态栏
      wofi                  # 应用启动器
      mako                  # 通知守护进程
      grim slurp swappy     # 截图录屏三件套
      hyprpaper             # 壁纸管理
      cliphist              # 剪贴板历史
      wlogout swaylock-effects # 登出与锁屏
      playerctl             # 媒体按键控制
      networkmanagerapplet  # 网络托盘
      pavucontrol           # 音量控制面板
      jq                    # 脚本级依赖工具
      hypr-toggle-pkg       # 🌟 自动注入我们上面的智能切换脚本
    ];

    # ── 将基础配置文件部署到系统的 /etc/hypr 中 ──────────────────
    environment.etc = {
      "hypr/apps.yaml".source = ../assets/hypr/apps.yaml;
    };

    # ── 🌟 核心：直接生成系统级的默认全局 Hyprland 配置 ─────────────
    # 这部分配置会自动作为全局底座加载，包含完整的快捷键以及【自动启动】
    environment.etc."hypr/hyprland.conf".text = ''
      # ── 1. 自动启动守护进程 (Exec-once) ───────────────────
      exec-once = waybar
      exec-once = mako
      exec-once = hyprpaper
      exec-once = nm-applet --indicator

      # 剪贴板历史自动保存
      exec-once = wl-paste --type text --watch cliphist store
      exec-once = wl-paste --type image --watch cliphist store

      # ── 2. 基础窗口与显示器配置（可根据你的硬件修改） ───────
      monitor=,preferred,auto,1

      # ── 3. F1-F12 智能快捷键绑定 ──────────────────────────
      # 这里直接调用 Nix 系统路径中编译好的 hypr-toggle 二进制
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

      # ── 4. 基础功能快捷键（根据你之前的 YAML 末尾映射） ─────
      bind = SUPER CTRL, s, togglesplit # 对应 ToggleSticky 逻辑或平铺切换
      bind = SUPER, q, exec, flameshot gui || grim -g "$(slurp)" - | swappy -f -

      # 允许引入用户个人的配置目录覆盖全局配置
      source = ~/.config/hypr/user-hyprland.conf
    '';
  };
}
