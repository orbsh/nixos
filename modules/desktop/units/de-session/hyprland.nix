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

  # 2. Alt+Tab 切换器（hyprshell，旧 hyprswitch 已改名，nixpkgs 只保留 hyprshell）
  switcher-pkg = pkgs.hyprshell;
  switcher-bin = "hyprshell";

  # 2b. hyprshell daemon 启动脚本：扫描 Hyprland socket 目录（不依赖 hyprctl/WAYLAND_DISPLAY，
  #     systemd 用户环境常缺 WAYLAND_DISPLAY），就绪后以常驻 daemon 模式运行 `hyprshell run`。
  hyprshell-startup = pkgs.writeShellScript "hyprshell-startup" ''
    # systemd 用户服务不继承 systemPackages 的 PATH，显式加入 sw/bin
    export PATH=/run/current-system/sw/bin:$PATH
    export XDG_RUNTIME_DIR=/run/user/$UID

    # 直接扫描实例 socket，而非 hyprctl（其需 WAYLAND_DISPLAY，systemd 用户环境往往缺失）
    sig=""
    for i in $(seq 1 50); do
      sig=$(basename "$(dirname "$(ls /run/user/$UID/hypr/*/.socket.sock 2>/dev/null | head -n1)")" 2>/dev/null)
      [ -n "$sig" ] && break
      sleep 0.1
    done
    [ -n "$sig" ] || exit 1

    export HYPRLAND_INSTANCE_SIGNATURE="$sig"
    exec hyprshell run
  '';

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
    # ── 会话触发：原生 start-hyprland 不建 graphical-session.target，
    #    dispatcher 永不触发 → 这里直接拉起 DE 组件入口 target（绕过 RefuseManualStart）
    wayland.windowManager.hyprland.extraExecOnce = [
      "systemctl --user start desktop-hyprland.target"
    ];

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

      # hyprshell（Alt+Tab 切换器）配置：纯 switch 模式，禁 overview/launcher
      xdg.configFile."hyprshell/config.ron".source = ../../assets/hyprshell/config.ron;
    };

    # hyprshell daemon：常驻注册 Alt+Tab 全局切换
    systemd.user.services.hyprshell = {
      description = "Hyprshell daemon (Alt+Tab window switcher)";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "exec";
        ExecStart = hyprshell-startup;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}