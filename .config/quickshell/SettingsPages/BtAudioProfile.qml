import QtQuick
import Quickshell.Io
import "../"

// High-quality (A2DP) or headset (HFP) profile of a connected Bluetooth audio device, via pactl.
SetSub {
    id: s
    property string address: ""
    property string card: ""
    property string active: ""
    property var profiles: ({})        // "a2dp" / "hfp" -> full profile name

    visible: card !== ""
    label: "Audio profile"
    hint: "Headset mode has a microphone but lower quality"

    function load() { p.running = true }
    Component.onCompleted: load()
    onAddressChanged: load()

    Process {
        id: p
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                s.card = ""
                try {
                    var key = s.address.toUpperCase().replace(/:/g, "_")
                    var cards = JSON.parse(text)
                    for (var i = 0; i < cards.length; i++) {
                        if (cards[i].name.toUpperCase().indexOf(key) < 0) continue
                        var pr = {}
                        for (var name in cards[i].profiles) {
                            var info = cards[i].profiles[name]
                            if (info.available === false) continue
                            if (name.indexOf("a2dp-sink") === 0 && !pr.a2dp) pr.a2dp = name
                            if (name.indexOf("headset-head-unit") === 0 && !pr.hfp) pr.hfp = name
                        }
                        s.profiles = pr
                        s.active = cards[i].active_profile
                        s.card = cards[i].name
                    }
                } catch (e) {}
            }
        }
    }
    Process { id: setter; onExited: s.load() }

    SetSeg {
        options: ["High quality", "Headset"]
        current: s.active.indexOf("headset") === 0 ? "Headset" : s.active.indexOf("a2dp") === 0 ? "High quality" : ""
        onPicked: v => {
            var target = v === "Headset" ? s.profiles.hfp : s.profiles.a2dp
            if (!target) return
            setter.command = ["pactl", "set-card-profile", s.card, target]
            setter.running = true
        }
    }
}
