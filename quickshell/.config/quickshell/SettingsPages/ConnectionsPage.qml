import QtQuick
import Quickshell.Io
import "../"

// Wi-Fi and Bluetooth: an on/off switch and a status line here, the full manager in its own app.
SetPage {
    id: page
    title: "CONNECTIONS"

    property bool wifiOn: false
    property string wifiName: ""
    property bool btOn: false
    property string btDevices: ""

    function refresh() { pWifi.running = true; pBt.running = true }
    function run(cmd) { runner.command = ["sh", "-c", cmd]; runner.running = true }

    Component.onCompleted: refresh()
    Timer { interval: 4000; running: true; repeat: true; onTriggered: page.refresh() }

    Process {
        id: pWifi
        command: ["sh", "-c", "nmcli -t -f WIFI g; nmcli -t -f TYPE,NAME connection show --active | grep -E '^(802-11-wireless|wifi)' | head -1 | cut -d: -f2-"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                page.wifiOn = l[0] === "enabled"
                page.wifiName = l.length > 1 ? l[1] : ""
            }
        }
    }
    Process {
        id: pBt
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off; bluetoothctl devices Connected | cut -d' ' -f3- | paste -sd, -"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                page.btOn = l[0] === "on"
                page.btDevices = l.length > 1 ? l[1].replace(/,/g, ", ") : ""
            }
        }
    }
    Process { id: runner; onRunningChanged: if (!running) page.refresh() }

    SetSection { text: "Wi-Fi" }
    SetRow {
        label: "Wi-Fi"
        hint: !page.wifiOn ? "Off" : (page.wifiName !== "" ? "Connected to " + page.wifiName : "On, not connected")
        SetToggle { checked: page.wifiOn; onToggled: v => page.run("nmcli radio wifi " + (v ? "on" : "off")) }
    }
    SetRow {
        label: "Networks"
        hint: "Pick a network, enter passwords, VPNs and advanced settings"
        SetButton { label: "Network editor"; onClicked: page.run("nm-connection-editor") }
    }

    SetSection { text: "Bluetooth" }
    SetRow {
        label: "Bluetooth"
        hint: !page.btOn ? "Off" : (page.btDevices !== "" ? "Connected: " + page.btDevices : "On, nothing connected")
        SetToggle { checked: page.btOn; onToggled: v => page.run("bluetoothctl power " + (v ? "on" : "off")) }
    }
    SetRow {
        label: "Devices"
        hint: "Pair, connect and remove devices"
        SetButton { label: "Bluetooth manager"; onClicked: page.run("blueman-manager") }
    }
}
