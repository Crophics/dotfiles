import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import "../"

// Bluetooth through BlueZ (Quickshell's native module), with our own pairing agent so
// passkey prompts show up here instead of in a separate app.
SetPage {
    id: page
    title: "BLUETOOTH"

    readonly property var adapter: Bluetooth.defaultAdapter
    property int tick: 0
    readonly property var devs: { tick; return adapter && adapter.devices ? (adapter.devices.values || []) : [] }
    readonly property var mine: devs.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: devs.filter(d => !(d.paired || d.bonded) && (showUnnamed || !isUnnamed(d)))
    property bool showUnnamed: false
    property string expanded: ""
    property string status: ""
    property var req: null              // pending pairing request from the agent
    property string sendPath: ""
    property string newName: ""

    function isUnnamed(d) { return d.name.replace(/-/g, ":").toUpperCase() === d.address.toUpperCase() }
    function glyph(icon) {
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphones") >= 0) return "󰋋"
        if (icon.indexOf("mouse") >= 0) return "󰍽"
        if (icon.indexOf("keyboard") >= 0) return "󰌌"
        if (icon.indexOf("phone") >= 0) return "󰏲"
        if (icon.indexOf("gaming") >= 0) return "󰊖"
        if (icon.indexOf("audio") >= 0) return "󰓃"
        if (icon.indexOf("computer") >= 0) return "󰍹"
        return "󰂱"
    }
    function kind(icon) {
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphones") >= 0) return "Headphones"
        if (icon.indexOf("mouse") >= 0) return "Mouse"
        if (icon.indexOf("keyboard") >= 0) return "Keyboard"
        if (icon.indexOf("phone") >= 0) return "Phone"
        if (icon.indexOf("gaming") >= 0) return "Gamepad"
        if (icon.indexOf("audio") >= 0) return "Speaker"
        if (icon.indexOf("computer") >= 0) return "Computer"
        return "Device"
    }
    function stateText(d) {
        return d.pairing ? "pairing…" : d.connected ? "connected" : "paired, not connected"
    }
    function battery(d) { return d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "" }
    function setAlias(path, alias) {
        runner.command = ["busctl", "--system", "set-property", "org.bluez", path, "org.bluez.Device1", "Alias", "s", alias]
        runner.running = true
    }

    Timer { interval: 1500; running: true; repeat: true; onTriggered: page.tick++ }
    Component.onCompleted: { if (adapter) { adapter.pairable = true; adapter.discovering = true } }
    Component.onDestruction: {
        if (adapter) adapter.discovering = false
        agent.running = false
    }

    Process { id: runner; onExited: page.tick++ }

    // ── pairing agent ──
    Process {
        id: agent
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/bt-agent.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                var f = line.trim().split(" ")
                if (f[0] === "CANCEL") { page.req = null; return }
                if (["CONFIRM", "PIN", "PASSKEY", "AUTH", "DISPLAY"].indexOf(f[0]) >= 0)
                    page.req = { kind: f[0], address: f[1], code: f[2] || "" }
            }
        }
    }
    function answer(text) { agent.write(text + "\n"); req = null }
    readonly property string reqName: {
        if (!req) return ""
        var d = devs.find(x => x.address.toUpperCase() === req.address.toUpperCase())
        return d ? d.name : req.address
    }

    Text {
        visible: !page.adapter
        width: parent.width
        text: "No Bluetooth adapter found"
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
    Text {
        visible: page.status !== ""
        width: parent.width
        text: page.status
        wrapMode: Text.WordWrap
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    // ── Adapter ──
    SetSection { text: "Adapter"; visible: page.adapter }
    SetRow {
        visible: page.adapter
        label: "Bluetooth"
        hint: page.adapter ? "hci0 · " + page.adapter.name : ""
        SetToggle { checked: page.adapter ? page.adapter.enabled : false; onToggled: v => { page.adapter.enabled = v; if (v) page.adapter.discovering = true } }
    }
    SetRow {
        visible: page.adapter && page.adapter.enabled
        label: "Name"
        hint: "How other devices see this laptop"
        SetTextField { id: adName; implicitWidth: 180; text: page.adapter ? page.adapter.name : "" }
        SetButton {
            label: "Apply"; primary: true
            enabled: page.adapter && adName.text !== "" && adName.text !== page.adapter.name
            onClicked: { runner.command = ["busctl", "--system", "set-property", "org.bluez", page.adapter.dbusPath, "org.bluez.Adapter1", "Alias", "s", adName.text]; runner.running = true }
        }
    }
    SetRow {
        visible: page.adapter && page.adapter.enabled
        label: "Visible to other devices"
        hint: "Needed when a device pairs by searching for this laptop"
        SetSeg {
            options: ["Off", "3 min", "Always"]
            current: !page.adapter || !page.adapter.discoverable ? "Off" : page.adapter.discoverableTimeout === 0 ? "Always" : "3 min"
            onPicked: v => {
                if (v === "Off") page.adapter.discoverable = false
                else { page.adapter.discoverableTimeout = v === "Always" ? 0 : 180; page.adapter.discoverable = true }
            }
        }
    }

    // ── My devices ──
    SetSection { text: "My devices"; visible: page.adapter && page.adapter.enabled }
    Repeater {
        model: page.adapter && page.adapter.enabled ? page.mine : []
        delegate: Column {
            id: dcol
            required property var modelData
            width: parent ? parent.width : 0
            spacing: 6
            readonly property bool open: page.expanded === modelData.address
            readonly property bool remembered: BluetoothState.rememberedDevices.indexOf(modelData.address) >= 0

            SetRow {
                clickable: true
                selected: dcol.open
                label: modelData.name
                hint: page.kind(modelData.icon) + " · " + page.stateText(modelData)
                leading: [Text { text: page.glyph(modelData.icon); color: Theme.accent2; font.family: Theme.iconFont; font.pixelSize: 16; width: 20; horizontalAlignment: Text.AlignHCenter }]
                onClicked: page.expanded = dcol.open ? "" : modelData.address
                Row {
                    visible: page.battery(modelData) !== ""
                    height: 26
                    spacing: 6
                    Item {
                        width: 20; height: 26
                        Rectangle {
                            id: shell
                            width: 17; height: 9; radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.textDim
                            Rectangle {
                                x: 2; y: 2; height: parent.height - 4; radius: 1
                                width: Math.max(1, (parent.width - 4) * (modelData.battery || 0))
                                color: Theme.textDim
                            }
                        }
                        Rectangle { x: shell.width + 1; width: 2; height: 4; radius: 1; anchors.verticalCenter: parent.verticalCenter; color: Theme.textDim }
                    }
                    Text { height: 26; verticalAlignment: Text.AlignVCenter; text: page.battery(modelData); color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1 }
                }
                SetButton {
                    label: modelData.connected ? "Disconnect" : "Connect"
                    primary: !modelData.connected
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }
            SetDetail {
                visible: dcol.open
                BtAudioProfile { visible: modelData.connected && page.kind(modelData.icon) !== "Mouse" && page.kind(modelData.icon) !== "Keyboard"; address: modelData.address }
                SetSub {
                    label: "Connect automatically"
                    hint: "Reconnects whenever it's in range"
                    SetToggle {
                        checked: dcol.remembered && modelData.trusted
                        onToggled: v => {
                            modelData.trusted = v
                            if (v) BluetoothState.remember(modelData.address); else BluetoothState.forget(modelData.address)
                        }
                    }
                }
                SetSub {
                    label: "Name"
                    hint: "Rename on this laptop only"
                    SetTextField { id: rn; implicitWidth: 200; text: modelData.name }
                    SetButton { label: "Apply"; primary: true; enabled: rn.text !== "" && rn.text !== modelData.name; onClicked: modelData.name = rn.text }
                }
                SetSub {
                    label: "Send a file"
                    SetTextField { id: sendF; implicitWidth: 200; placeholder: "~/Documents/file.pdf" }
                    SetButton {
                        label: "Send"; primary: true; enabled: sendF.text !== "" && modelData.connected
                        onClicked: Quickshell.execDetached(["blueman-sendto", "--device=" + modelData.address, sendF.text.replace(/^~/, Quickshell.env("HOME"))])
                    }
                }
                KV { label: "Address"; value: modelData.address }
                Row {
                    spacing: 8
                    SetButton { label: "Block"; onClicked: modelData.blocked = true }
                    SetButton { label: "Forget device"; onClicked: { BluetoothState.forget(modelData.address); modelData.forget(); page.expanded = "" } }
                }
            }
        }
    }
    Text {
        visible: page.adapter && page.adapter.enabled && page.mine.length === 0
        text: "No paired devices yet. Put a device in pairing mode and pick it below."
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    // ── Add a device ──
    SetSection { text: "Add a device"; visible: page.adapter && page.adapter.enabled }
    SetRow {
        visible: page.adapter && page.adapter.enabled
        label: page.adapter && page.adapter.discovering ? "Searching…" : "Search paused"
        hint: page.nearby.length + " nearby"
        SetButton { label: page.adapter && page.adapter.discovering ? "Stop" : "Search"; onClicked: page.adapter.discovering = !page.adapter.discovering }
    }
    Rectangle {
        visible: page.req !== null
        width: parent.width
        height: sheet.implicitHeight + 28
        radius: Theme.radius
        color: Theme.alpha(Theme.accent, 0.07)
        border.width: 1
        border.color: Theme.accent
        Column {
            id: sheet
            x: 14; y: 14
            width: parent.width - 28
            spacing: 10
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                text: !page.req ? "" :
                    page.req.kind === "CONFIRM" ? "Pairing with " + page.reqName + ". Check that this code matches the one on the device."
                    : page.req.kind === "DISPLAY" ? "Type this code on " + page.reqName + " to finish pairing."
                    : page.req.kind === "AUTH" ? page.reqName + " wants to pair with this laptop."
                    : "Enter the code for " + page.reqName + "."
            }
            Text {
                visible: page.req && (page.req.kind === "CONFIRM" || page.req.kind === "DISPLAY")
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.req ? page.req.code : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 26
                font.letterSpacing: 8
            }
            SetTextField {
                id: codeField
                visible: page.req && (page.req.kind === "PIN" || page.req.kind === "PASSKEY")
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: 180
                placeholder: "Code"
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                SetButton {
                    visible: page.req && page.req.kind !== "DISPLAY"
                    label: page.req && page.req.kind === "AUTH" ? "Allow" : page.req && (page.req.kind === "PIN" || page.req.kind === "PASSKEY") ? "Send" : "Pair"
                    primary: true
                    onClicked: {
                        if (page.req.kind === "PIN") page.answer("PIN " + codeField.text)
                        else if (page.req.kind === "PASSKEY") page.answer("KEY " + codeField.text)
                        else page.answer("YES")
                        codeField.text = ""
                    }
                }
                SetButton { label: "Cancel"; onClicked: page.answer("NO") }
            }
        }
    }
    Repeater {
        model: page.adapter && page.adapter.enabled ? page.nearby : []
        delegate: SetRow {
            required property var modelData
            label: modelData.name
            hint: modelData.pairing ? "Pairing…" : page.kind(modelData.icon)
            leading: [Text { text: page.glyph(modelData.icon); color: Theme.accent2; font.family: Theme.iconFont; font.pixelSize: 16; width: 20; horizontalAlignment: Text.AlignHCenter }]
            SetButton { label: modelData.pairing ? "Cancel" : "Pair"; primary: !modelData.pairing; onClicked: modelData.pairing ? modelData.cancelPair() : modelData.pair() }
        }
    }
    SetRow {
        visible: page.adapter && page.adapter.enabled
        label: "Show unnamed devices"
        hint: "Hidden by default to cut noise"
        SetToggle { checked: page.showUnnamed; onToggled: v => page.showUnnamed = v }
    }

    // ── Internet over Bluetooth ──
    SetSection { text: "Internet over Bluetooth"; visible: page.adapter && page.adapter.enabled && page.phones.length > 0 }
    Repeater {
        model: page.adapter && page.adapter.enabled ? page.phones : []
        delegate: SetRow {
            required property var modelData
            label: modelData.name
            hint: "Use this phone's mobile data. Turn on Bluetooth tethering on the phone first"
            wrapHint: true
            SetButton {
                label: "Connect"; primary: true
                onClicked: {
                    runner.command = ["sh", "-c",
                        "id=$(nmcli -t -f NAME,TYPE connection show | grep ':bluetooth$' | cut -d: -f1 | while IFS= read -r n; do "
                        + "[ \"$(nmcli -g bluetooth.bdaddr connection show id \"$n\")\" = \"$1\" ] && echo \"$n\" && break; done); "
                        + "[ -z \"$id\" ] && id=\"$2 (Bluetooth)\" && nmcli connection add type bluetooth con-name \"$id\" bluetooth.bdaddr \"$1\" bluetooth.type panu autoconnect no; "
                        + "nmcli connection up id \"$id\"", "sh", modelData.address, modelData.name]
                    runner.running = true
                }
            }
        }
    }
    readonly property var phones: mine.filter(d => d.icon.indexOf("phone") >= 0)

    // ── Blocked ──
    SetSection { text: "Blocked devices"; visible: page.blocked.length > 0 }
    readonly property var blocked: devs.filter(d => d.blocked)
    Repeater {
        model: page.blocked
        delegate: SetRow {
            required property var modelData
            label: modelData.name
            hint: modelData.address
            SetButton { label: "Unblock"; onClicked: modelData.blocked = false }
        }
    }
}
