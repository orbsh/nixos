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
  switcher-pkg = if builtins.hasAttr "hyprshell" pkgs then pkgs.hyprshell else pkgs.hyprswitch;
  switcher-bin = if builtins.hasAttr "hyprshell" pkgs then "hyprshell" else "hyprswitch";

  # 3. Lua 配置：读取资产模板，注入占位符（切换器/自启）
  extraExecOnceLua = lib.concatMapStringsSep "\n"
    (c: "    hl.exec_cmd(\"${c}\")") cfg.extraExecOnce;

  hyprlandLua = lib.replaceStrings
    [ "@HYPR_TOGGLE@" "@SWITCHER@" "@EXTRA_EXEC_ONCE@" ]
    [ "hypr-toggle" switcher-bin extraExecOnceLua ]
    (builtins.readFile ../../assets/hypr/hyprland.lua);

in {
  options.wayland.windowManager.hyprland.extraExecOnce = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "额外的 Hyprland 自启命令（exec-once），供其他单元注入";
  };

  config = {
    # 活跃谓词：Hyprland 进程在跑 = Hyprland 会话激活（供 de-session dispatcher 使用）
    desktop.sessions.hyprland.predicate = "${pkgs.procps}/bin/pgrep -f Hyprland";

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
      grim slurp swappy
      hyprpaper cliphist
      wlogout swaylock-effects
      playerctl networkmanagerapplet pavucontrol jq
      hypr-toggle-pkg     # 注入 F1-F12 脚本
      switcher-pkg        # 🌟 Alt+Tab 高级切换器包
    ];

    home-manager.users.${user} = {
      # ── 输入法环境变量 ──────────────────────────────────
      home.sessionVariables = {
        XMODIFIERS = "@im=fcitx";
        GTK_IM_MODULE = "fcitx";
        QT_IM_MODULE = "fcitx";
      };

      # Hyprland 主配置（Lua 声明式；经 ~/.config/hypr 符号链接落盘）
      xdg.configFile."hypr/hyprland.lua".text = hyprlandLua;

      xdg.configFile."hypr/apps.yaml".source = ../../assets/hypr/apps.yaml;
    };
  };
}