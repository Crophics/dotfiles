import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Window look: opacity, borders, corners and gaps. Values are saved to
// state/windows.json; scripts/apply-window-prefs.sh turns them into Hyprland settings.
SetPage {
    id: page
    title: "WINDOWS"

    property real opacity_: 0.9
    property int borderSize: 2
    property int rounding: 8
    property int gapsIn: 4
    property bool animations: true
    property string animSpeed: "normal"

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: home + "/.config/hypr/scripts/apply-window-prefs.sh"

    property var pendingArgs: null     // apply script arguments, run once the save has finished

    FileView {
        id: file
        path: page.home + "/.config/quickshell/state/windows.json"
        printErrors: false
        onSaved: {
            if (page.pendingArgs) {
                Quickshell.execDetached(page.pendingArgs)
                page.pendingArgs = null
            }
        }
        onLoaded: {
            try {
                var s = JSON.parse(file.text())
                if (typeof s.opacity === "number") page.opacity_ = s.opacity
                if (typeof s.borderSize === "number") page.borderSize = s.borderSize
                if (typeof s.rounding === "number") page.rounding = s.rounding
                if (typeof s.gapsIn === "number") page.gapsIn = s.gapsIn
                if (typeof s.animations === "boolean") page.animations = s.animations
                if (typeof s.animSpeed === "string") page.animSpeed = s.animSpeed
            } catch (e) {
                console.warn("windows: could not read saved state:", e)
            }
        }
        onLoadFailed: error => {
            // First run: start from what the shell is using right now.
            page.opacity_ = Theme.bgAlpha
        }
    }

    // Save, then apply. `what` is "opacity" when the window opacity changed.
    function commit(what) {
        page.pendingArgs = what ? [page.script, what] : [page.script]
        file.setText(JSON.stringify({
            opacity: Math.round(page.opacity_ * 100) / 100,
            borderSize: page.borderSize,
            rounding: page.rounding,
            gapsIn: page.gapsIn,
            animations: page.animations,
            animSpeed: page.animSpeed
        }))
    }

    SetSection { text: "Opacity" }
    SetRow {
        label: "Window opacity"
        hint: "Also applies to the bar, panels and launcher"
        SetSlider {
            from: 0.4; to: 1; step: 0.05
            value: page.opacity_
            displayText: Math.round(value * 100) + "%"
            onMoved: v => { page.opacity_ = v; Theme.bgAlpha = v }
            onCommitted: page.commit("opacity")
        }
    }
    SetRow {
        label: "Presets"
        SetSeg {
            options: ["100%", "90%", "80%", "70%", "50%"]
            current: Math.round(page.opacity_ * 100) + "%"
            onPicked: v => { page.opacity_ = parseInt(v) / 100; Theme.bgAlpha = page.opacity_; page.commit("opacity") }
        }
    }

    SetSection { text: "Borders and corners" }
    SetRow {
        label: "Border"
        hint: "Accent border on the focused window. 0 turns it off"
        SetSlider {
            from: 0; to: 6; step: 1; unit: " px"
            value: page.borderSize
            onMoved: v => { page.borderSize = v; page.commit() }
        }
    }
    SetRow {
        label: "Corner radius"
        SetSlider {
            from: 0; to: 20; step: 1; unit: " px"
            value: page.rounding
            onMoved: v => { page.rounding = v; page.commit() }
        }
    }
    SetRow {
        label: "Gap between windows"
        SetSlider {
            from: 0; to: 20; step: 1; unit: " px"
            value: page.gapsIn
            onMoved: v => { page.gapsIn = v; page.commit() }
        }
    }

    SetSection { text: "Animations" }
    SetRow {
        label: "Animations"
        hint: "Windows pop in and out, workspaces slide"
        SetToggle { checked: page.animations; onToggled: v => { page.animations = v; page.commit("anim") } }
    }
    SetRow {
        label: "Animation speed"
        hint: "Fast is snappier, relaxed is slower"
        enabled: page.animations
        SetSeg {
            options: ["fast", "normal", "relaxed"]
            current: page.animSpeed
            onPicked: v => { page.animSpeed = v; page.commit("anim") }
        }
    }

    Item { width: 1; height: 6 }
    SetButton {
        label: "Reset windows"
        onClicked: {
            page.opacity_ = 0.9; page.borderSize = 2; page.rounding = 8; page.gapsIn = 4
            page.animations = true; page.animSpeed = "normal"
            Theme.bgAlpha = 0.9
            page.commit("opacity")
        }
    }
}
