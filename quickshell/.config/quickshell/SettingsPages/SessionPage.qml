import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Locking and sleeping: idle timers and what closing the lid does. Values are saved to
// state/session.json; scripts/apply-session-prefs.sh turns them into a hypridle config.
SetPage {
    id: page
    title: "SESSION"

    property int lockMin: 5
    property int suspendMin: 15
    property int graceSec: 60

    readonly property string home: Quickshell.env("HOME")

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
            } catch (e) {
                console.warn("session: could not read saved state:", e)
            }
        }
    }

    function minutes(m) { return m === 0 ? "Never" : m + " min" }

    function commit() {
        file.setText(JSON.stringify({ lockMin: page.lockMin, suspendMin: page.suspendMin, graceSec: page.graceSec }))
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

    SetSection { text: "Now" }
    SetRow {
        label: "Lock the screen"
        SetButton { label: "Lock"; onClicked: Quickshell.execDetached(["loginctl", "lock-session"]) }
    }
    SetRow {
        label: "Suspend the laptop"
        hint: "Locks first. Wake it with a key or the touchpad"
        SetButton { label: "Suspend"; onClicked: Quickshell.execDetached([page.home + "/.config/hypr/scripts/suspend.sh"]) }
    }
}
