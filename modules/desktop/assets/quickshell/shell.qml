// Quickshell 0.3 desktop shell — 启动器 + 通知（替代 wofi / mako）
// ================================================================================
// 组件：顶部状态栏(时钟) / 应用启动器 / 通知卡片
// 触发：启动器由 Hyprland `SUPER, SPACE -> quickshell ipc call default toggleLauncher`
// 说明：
//   启动器  -> DesktopEntries.applications.values（组件级数组，异步填充），查询过滤，
//             Quickshell.execDetached 用 entry.command.join(" ") 拉起
//   通知    -> NotificationServer（org.freedesktop.Notifications daemon），dismiss 关闭
// ⚠ 已实测：UntypedObjectModel 无 .count/.get，须经 .values 索引迭代（len + [i]）
// ⚠ 本 quickshell 0.3.0 依赖闭包不含 QtQuick.Controls/Layouts → 只用 QtQuick 基础类型
// ================================================================================
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: root

    // ── IPC：quickshell ipc call default toggleLauncher ──
    IpcHandler {
        target: "default"
        function toggleLauncher(): void { launcher.toggle() }
    }

    // ── 顶部状态栏 ─────────────────────────────────────────
    PanelWindow {
        id: bar
        anchors { top: true; left: true; right: true }
        height: 30
        color: "#202020"

        Text {
            id: clockText
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            color: "#cccccc"
            font.pixelSize: 13
        }
        Text {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            color: "#888888"
            font.pixelSize: 12
            text: "QS shell"
        }
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
            Component.onCompleted: onTriggered()
        }
    }

    // ── 应用启动器 ─────────────────────────────────────────
    PopupWindow {
        id: launcher
        anchor.window: bar
        anchor.rect.x: parentWindow.width / 2 - width / 2
        anchor.rect.y: parentWindow.height + 4
        width: 560
        height: Math.min(list.count, 8) * 52 + 64 + 8
        visible: false
        grabFocus: true

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: "#282828"
            border.color: "#383838"

            Column {
                anchors { fill: parent; margins: 8 }
                spacing: 6

                // 搜索输入
                Rectangle {
                    width: launcher.width - 16
                    height: 32
                    radius: 6
                    color: "#1e1e1e"
                    border.color: "#3a3a3a"
                    TextInput {
                        id: search
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        color: "#eeeeee"
                        selectByMouse: true
                        onTextChanged: rebuild(text)
                        Keys.onReturnPressed: launchCurrent()
                        Keys.onEscapePressed: launcher.visible = false
                    }
                }

                ListView {
                    id: list
                    width: launcher.width - 16
                    height: Math.min(parent.height - 40, count * 52)
                    model: params
                    clip: true

                    Keys.onReturnPressed: launchCurrent()

                    delegate: Rectangle {
                        required property string name
                        required property string comment
                        required property string command
                        width: list.width
                        height: 52
                        radius: 6
                        color: list.currentIndex === index ? "#3a3a3a" : "transparent"

                        Column {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            leftPadding: 10
                            rightPadding: 10
                            Text {
                                width: parent.width - 20
                                text: name
                                color: "#eeeeee"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width - 20
                                text: comment
                                visible: text.length > 0
                                color: "#888888"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = index
                            onClicked: { list.currentIndex = index; launchCurrent() }
                        }
                    }
                }
            }
        }

        // ── 数据：DesktopEntries.values（异步填充）→ 查询过滤 ──
        ListModel { id: params }

        function currentApps() {
            var m = DesktopEntries.applications
            return m ? m.values : []
        }

        function rebuild(q) {
            params.clear()
            q = (q || "").trim().toLowerCase()
            var v = currentApps()
            for (var i = 0; i < v.length; ++i) {
                var e = v[i]
                if (!e || e.noDisplay) continue
                var hay = ((e.name || "") + " " + (e.genericName || "") + " " + (e.comment || "")).toLowerCase()
                if (q === "" || hay.indexOf(q) >= 0) {
                    var cmd = (e.command || "").join ? e.command.join(" ") : (e.command || "")
                    params.append({ name: e.name || "", comment: e.comment || "", command: cmd })
                    if (params.count >= 50) break
                }
            }
        }

        function toggle() {
            visible = !visible
            if (visible) {
                search.text = ""
                rebuild("")                 // values 异步填充，每次打开重读即最新
                search.forceActiveFocus()
            }
        }

        function launchCurrent() {
            if (list.currentIndex >= 0 && list.currentIndex < params.count) {
                var cmd = params.get(list.currentIndex).command
                if (cmd) Quickshell.execDetached(cmd)
            }
            visible = false
        }

        // 首次填充：等 DesktopEntries 异步枚举完成后建索引
        Component.onCompleted: Qt.callLater(function(){ rebuild("") })
    }

    // ── 通知：屏顶居中叠加 ─────────────────────────────────
    PopupWindow {
        id: notifWin
        anchor.window: bar
        anchor.rect.x: parentWindow.width / 2 - width / 2
        anchor.rect.y: parentWindow.height + 8
        width: 380
        height: notifRepeater.count * 84 + 8
        visible: notifRepeater.count > 0
        color: "transparent"

        Column {
            id: notifCol
            spacing: 6
            Repeater {
                id: notifRepeater
                model: NotificationServer.trackedNotifications
                delegate: Rectangle {
                    required property var modelData
                    id: card
                    width: 380
                    height: 78
                    radius: 8
                    color: "#282828"
                    border.color: "#383838"

                    Column {
                        anchors { fill: parent; margins: 8 }
                        spacing: 2
                        Row {
                            width: parent.width
                            spacing: 6
                            Text {
                                text: modelData.appName || ""
                                width: card.width - 40
                                color: "#cccccc"
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "×"
                                color: "#aaaaaa"
                                font.pixelSize: 14
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: modelData.dismiss()
                                }
                            }
                        }
                        Text {
                            text: modelData.summary || ""
                            width: parent.width
                            color: "#ffffff"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.body || ""
                            visible: text.length > 0
                            width: parent.width
                            color: "#aaaaaa"
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // 自动关闭：Low 8s / Normal 5s / Critical(2) 保持
                    Timer {
                        interval: (modelData.urgency || 0) === 0 ? 8000 : 5000
                        running: (modelData.urgency || 0) !== 2
                        repeat: false
                        onTriggered: modelData.dismiss()
                    }
                }
            }
        }
    }
}