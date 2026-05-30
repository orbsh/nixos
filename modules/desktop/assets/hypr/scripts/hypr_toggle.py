#!/usr/bin/env python3
"""
hypr_toggle.py - 智能窗口切换脚本
用法: python3 hypr_toggle.py <数字>
根据 ~/.config/hypr/apps.yaml 中的规则，实现应用窗口的启动/聚焦/切换。
"""

import json
import subprocess
import yaml
import sys
import re
import os

CONFIG_PATH = os.path.expanduser("~/.config/hypr/apps.yaml")
FALLBACK_CONFIG_PATH = "/etc/hypr/apps.yaml"


def load_config():
    """优先加载用户配置，回退到系统配置"""
    path = CONFIG_PATH if os.path.exists(CONFIG_PATH) else FALLBACK_CONFIG_PATH
    with open(path, 'r') as f:
        return yaml.safe_load(f)


def get_hypr_clients():
    """获取所有 Hyprland 客户端窗口列表"""
    out = subprocess.check_output(["hyprctl", "clients", "-j"])
    return json.loads(out)


def get_active_window():
    """获取当前活动窗口"""
    out = subprocess.check_output(["hyprctl", "activewindow", "-j"])
    return json.loads(out)


def match_filter(client, filters):
    """检查窗口是否匹配规则中的所有过滤器（AND 逻辑）

    参考 Nushell flt 实现，按空白分割谓词：
      [not] field operator value
    支持操作符：==  !=  =~  starts-with
    """
    for f in filters:
        tokens = re.split(r'\s+', f.strip())
        negate = False
        if tokens[0] == 'not':
            negate = True
            tokens = tokens[1:]

        if len(tokens) < 3:
            continue

        field, op, value = tokens[0], tokens[1], tokens[2]
        val = client.get(field, "") or ""

        if op == '==':
            result = val == value
        elif op == '!=':
            result = val != value
        elif op == '=~':
            result = bool(re.search(value, val))
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
    """根据键号切换/聚焦应用窗口"""
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
        print(f"未找到键号 {key_num} 的规则")
        return

    clients = get_hypr_clients()
    matched_clients = [c for c in clients if match_filter(c, rule.get('filter', []))]
    active = get_active_window()
    active_addr = active.get("address")

    if not matched_clients:
        # 未启动：执行启动命令
        cmd = rule.get('cmd')
        if cmd and isinstance(cmd, list) and len(cmd) > 0:
            print(f"启动: {' '.join(cmd)}")
            subprocess.Popen(cmd)
        elif cmd and isinstance(cmd, str) and cmd.strip():
            print(f"启动: {cmd}")
            subprocess.Popen(cmd, shell=True)
        else:
            print(f"规则 {key_num} 没有配置 cmd，仅聚焦已有窗口")
    else:
        # 已启动：检查当前焦点
        is_focused = any(c.get('address') == active_addr for c in matched_clients)

        if is_focused:
            # 已聚焦：在组内切换（适用于 Group）
            print("已在焦点，切换组内窗口")
            subprocess.run(["hyprctl", "dispatch", "changegroupactive", "f"])
        else:
            # 未聚焦：跳转到匹配的窗口
            target_addr = matched_clients[0].get('address')
            print(f"聚焦窗口: {target_addr}")
            subprocess.run(["hyprctl", "dispatch", "focuswindow", f"address:{target_addr}"])


if __name__ == "__main__":
    if len(sys.argv) > 1:
        try:
            toggle_app(int(sys.argv[1]))
        except ValueError:
            print("用法: python3 hypr_toggle.py <数字>")
            sys.exit(1)
    else:
        print("用法: python3 hypr_toggle.py <数字>")
        sys.exit(1)