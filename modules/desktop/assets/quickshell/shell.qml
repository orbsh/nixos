// Quickshell 0.3 desktop shell — 初始骨架（Hyprland 会话内单实例长驻）
// ============================================================================
// 架构借鉴 Omarchy shell 的两个核心思想（非抄代码）：
//   1. 单实例长驻：Hyprland 自启一次，面板/叠加层内联进同一个进程，避免重复冷启动。
//   2. IPC 优先：外部脚本通过 `quickshell -i <js>` 调用进程内命令，不要每次 spawn 新进程。
// ============================================================================
// ⚠ 这是框架骨架，尚未在真实会话中启动验证。
//   首次在 Hyprland 上登录后，请对照 Quickshell 0.3 官方文档校验/迭代：
//     - ShellRoot / Panel 的属性与锚点语义
//     - Hyprland 会话集成（下方 import Quickshell.Hyprland 被注释，确认编译含 hyprland 支持再启用）

import Quickshell
import QtQuick
// import Quickshell.Hyprland   // 可选：Hyprland IPC（workspace/window 事件源）——确认 build 含 hyprland 再启用

ShellRoot {
    id: root

    // ── 顶部状态栏占位 ──────────────────────────────────────
    // TODO: 时钟 / 工作区指示 / 系统托盘 / 快速设置 等组件填充
    Panel {
        id: bar
        anchors { top: true; left: true; right: true; }
        height: 32
        color: "#202020"

        // 占位文本，接入真实组件后移除
        Text {
            anchors.centerIn: parent
            color: "#cccccc"
            text: "Quickshell skeleton — edit shell.qml"
        }
    }
}