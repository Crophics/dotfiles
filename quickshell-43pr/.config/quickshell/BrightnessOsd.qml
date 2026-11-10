import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Brightness popup, styled like the volume popup in VolumeOsd.qml.
// Triggered over IPC (the brightness keys call these):
// The keys run hypr/scripts/brightness.sh directly (as fast as the volume keys); this popup
// watches the backlight file and shows itself whenever the brightness changes.
//   qs ipc call brightness quiet N  ignore changes for N ms (used by the idle dim fade)
//   qs ipc call brightness show     just show the current level
Scope {
    id: root

    property real level: 0
    property bool showing: false

    property int step: 5          // percent per key press (saved, set in Settings > Popups)
    property int timeout: 1200    // ms the popup stays up (saved)
    readonly property int topGap: 30

    // brightnessctl -m prints "device,class,current,percent,max"
    function parse(text) {
        var f = text.trim().split("\n").pop().split(",")
        if (f.length < 4) return
        var pct = parseInt(f[3])
        if (isNaN(pct)) return
        root.level = Math.max(0, Math.min(1, pct / 100))
        root.showing = true
        hideTimer.restart()
    }

    function refresh() {
        if (proc.running) return
        proc.command = ["brightnessctl", "-m"]
        proc.running = true
    }

    // Backlight files: the popup follows them, so any change shows it.
    property string device: ""
    property real maxLevel: 0
    property bool armed: false      // the first read at start-up must not pop up
    property bool quiet: false

    Timer { id: quietTimer; onTriggered: root.quiet = false }

    FileView {
        id: maxFile
        path: root.device === "" ? "" : "/sys/class/backlight/" + root.device + "/max_brightness"
        printErrors: false
        onLoaded: root.maxLevel = parseInt(maxFile.text()) || 0
    }
    FileView {
        id: levelFile
        path: root.device === "" ? "" : "/sys/class/backlight/" + root.device + "/brightness"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var v = parseInt(levelFile.text())
            if (isNaN(v) || root.maxLevel <= 0) return
            root.level = Math.max(0, Math.min(1, v / root.maxLevel))
            if (root.armed && !root.quiet) {
                root.showing = true
                hideTimer.restart()
            }
            root.armed = true
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                var f = text.trim().split("\n").pop().split(",")
                if (root.device === "" && f.length > 0) { root.device = f[0]; return }   // start-up probe: no popup
                root.parse(text)
            }
        }
    }

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/brightness-state.json"

    function saveState() {
        stateFile.setText(JSON.stringify({ step: root.step, timeout: root.timeout }))
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                if (typeof s.step === "number") root.step = Math.max(1, Math.min(20, Math.round(s.step)))
                if (typeof s.timeout === "number") root.timeout = Math.max(600, Math.min(5000, Math.round(s.timeout)))
            } catch (e) {
                console.warn("brightnessosd: could not read saved state:", e)
            }
        }
    }

    Timer {
        id: hideTimer
        interval: root.timeout
        onTriggered: root.showing = false
    }

    IpcHandler {
        target: "brightness"
        function show(): void { root.refresh() }
        function quiet(ms: int): void { root.quiet = true; quietTimer.interval = ms; quietTimer.restart() }
    }

    Component.onCompleted: refresh()

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: root.topGap + 28 + 20
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}      // never blocks clicks

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "brightnessosd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: card
                width: 320
                height: 28
                radius: 36
                color: Theme.bg
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: root.topGap
                transformOrigin: Item.Top
                opacity: root.showing ? 1 : 0
                visible: opacity > 0
                scale: root.showing ? 1 : 0.9

                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Text {
                    id: icon
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.level < 0.34 ? "󰃞" : root.level < 0.67 ? "󰃟" : "󰃠"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 20
                    color: Theme.text
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.level * 100) + "%"
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.text
                }

                Rectangle {
                    anchors.left: icon.right
                    anchors.leftMargin: 15
                    anchors.right: parent.right
                    anchors.rightMargin: 68
                    anchors.verticalCenter: parent.verticalCenter
                    height: 5
                    radius: 4
                    color: "#555555"

                    Rectangle {
                        width: parent.width * root.level
                        height: parent.height
                        radius: 4
                        color: Theme.text
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }
    }
}
