import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Power: profile and battery, plus locking and sleeping (idle timers, lid, low-battery actions).
// Session values are saved to state/session.json; scripts/apply-session-prefs.sh turns them into a hypridle config.
SetPage {
    id: page
    title: "POWER"

    property int lockMin: 5
    property int suspendMin: 15
    property int graceSec: 60
    property int dimSec: 30

    readonly property string home: Quickshell.env("HOME")
    readonly property var nt: Refs.notifications

    FileView {
        id: file
        path: page.home + "/.config/quickshell/state/session.json"
        printErrors: false
        onSaved: Quickshell.execDetached([page.home + "/.config/hypr/scripts/apply-session-prefs.sh"])
        onLoaded: {
            try {
                var s = JSON.parse(file.text())
                if (typeof s.lockMin === "number") page.lockMin = s.lockMin
                if (typeof s.suspendMin === "number") page.suspendMin = s.suspendMin
                if (typeof s.graceSec === "number") page.graceSec = s.graceSec
                if (typeof s.dimSec === "number") page.dimSec = s.dimSec
                else if (s.dim === false) page.dimSec = 0
            } catch (e) {
                console.warn("session: could not read saved state:", e)
            }
        }
    }

    function minutes(m) { return m === 0 ? "Never" : m + " min" }

    function commit() {
        file.setText(JSON.stringify({ lockMin: page.lockMin, suspendMin: page.suspendMin, graceSec: page.graceSec, dimSec: page.dimSec }))
    }

    property string profile: "balanced"
    property var profilesAvailable: []
    property int level: 0
    property string chargeState: ""
    property bool hasBattery: false
    readonly property var profileOptions: [
        { id: "power-saver", label: "Power saver" }, { id: "balanced", label: "Balanced" }, { id: "performance", label: "Performance" }
    ]

    function refresh() { pProf.running = true; pBat.running = true }
    Component.onCompleted: { refresh(); pList.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.refresh() }
    Process { id: pProf; command: ["powerprofilesctl", "get"]; stdout: StdioCollector { onStreamFinished: page.profile = text.trim() } }
    Process {
        id: pList
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var ids = []
                text.split("\n").forEach(l => { var m = l.match(/^[* ]\s*([a-z-]+):/); if (m) ids.push(m[1]) })
                page.profilesAvailable = ids
            }
        }
    }
    Process {
        id: pBat
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -r \"$b/capacity\" ] && echo $(cat \"$b/capacity\") $(cat \"$b/status\") && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(" ")
                page.hasBattery = p.length >= 2 && p[0] !== ""
                if (page.hasBattery) { page.level = parseInt(p[0]); page.chargeState = p.slice(1).join(" ") }
            }
        }
    }
    Process { id: setProf; onExited: page.refresh() }

    SetSection { text: "Performance" }
    SetRow {
        label: "Power profile"
        hint: "Power saver is quieter and lasts longer. Performance is fastest"
        SetSeg {
            options: page.profileOptions.filter(o => page.profilesAvailable.length === 0 || page.profilesAvailable.indexOf(o.id) >= 0).map(o => o.label)
            current: (page.profileOptions.find(o => o.id === page.profile) || {}).label || ""
            onPicked: v => { var o = page.profileOptions.find(x => x.label === v); page.profile = o.id; setProf.command = ["powerprofilesctl", "set", o.id]; setProf.running = true }
        }
    }
    SetRow {
        visible: page.hasBattery
        label: "Battery"
        hint: page.chargeState
        Text { height: 26; verticalAlignment: Text.AlignVCenter; text: page.level + "%"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.letterSpacing: 1 }
    }

    SetSection { text: "When idle" }
    SetRow {
        label: "Lock screen after"
        SetSlider {
            from: 0; to: 30; step: 1
            value: page.lockMin
            displayText: page.minutes(value)
            onMoved: v => page.lockMin = v
            onCommitted: page.commit()
        }
    }
    SetRow {
        label: "Suspend after"
        hint: "Counted from the start of the idle time"
        SetSlider {
            from: 0; to: 60; step: 1
            value: page.suspendMin
            displayText: page.minutes(value)
            onMoved: v => page.suspendMin = v
            onCommitted: page.commit()
        }
    }

    SetRow {
        label: "Dim the screen before that"
        hint: "The screen fades down this long before the first timer. Any key or touch brings it back"
        SetSlider {
            from: 0; to: 120; step: 5
            value: page.dimSec
            displayText: value === 0 ? "Off" : value + " s"
            onMoved: v => page.dimSec = v
            onCommitted: page.commit()
        }
    }

    SetSection { text: "Lid" }
    SetRow {
        label: "Skip lock if reopened within"
        hint: "Closing the lid always suspends. A quick close and open shows the desktop"
        SetSlider {
            from: 0; to: 300; step: 5
            value: page.graceSec
            displayText: value === 0 ? "Always lock" : value + " s"
            onMoved: v => page.graceSec = v
            onCommitted: page.commit()
        }
    }

    SetSection { text: "Low battery" }
    SetRow {
        label: "Low battery warning"
        hint: "A notification when the charge falls to this level on battery"
        SetSlider {
            from: 10; to: 50; step: 5; unit: "%"
            value: page.nt?.warnPct ?? 20
            onMoved: v => {
                page.nt.warnPct = v
                if (page.nt.critPct > v) page.nt.critPct = v      // keep critical at or below the warning
                page.nt.saveSettings()
            }
        }
    }
    SetRow {
        label: "Critical warning"
        hint: "A second, urgent notification"
        SetSlider {
            from: 5; to: 40; step: 5; unit: "%"
            value: page.nt?.critPct ?? 15
            onMoved: v => {
                page.nt.critPct = Math.min(v, page.nt.warnPct)
                if (page.nt.suspendPct > page.nt.critPct) page.nt.suspendPct = page.nt.critPct
                page.nt.saveSettings()
            }
        }
    }
    SetRow {
        label: "Suspend at"
        hint: "Lock and sleep by itself to protect your work. Off by default"
        SetSlider {
            from: 0; to: 20; step: 1
            value: page.nt?.suspendPct ?? 0
            displayText: value === 0 ? "Off" : value + "%"
            onMoved: v => { page.nt.suspendPct = Math.min(v, page.nt.critPct); page.nt.saveSettings() }
        }
    }

    SetSection { text: "Now" }
    SetRow {
        label: "Lock the screen"
        SetButton { label: "Lock"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/qylock/lock.sh"]) }
    }
    SetRow {
        label: "Suspend the laptop"
        hint: "Locks first. Wake it with a key or the touchpad"
        SetButton { label: "Suspend"; onClicked: Quickshell.execDetached([page.home + "/.config/hypr/scripts/suspend.sh"]) }
    }
}
