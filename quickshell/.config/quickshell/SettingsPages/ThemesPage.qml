import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Colours: follow the wallpaper or use a preset, light or dark. Runs ~/.config/43pr/bin/theme.py.
SetPage {
    id: page
    title: "THEMES"

    readonly property string home: Quickshell.env("HOME")
    readonly property string theme: home + "/.config/43pr/bin/theme.py"
    property var presets: []           // [{ name, desc }]
    property bool colorGen: true
    property bool dark: true
    property string mode: "wallpaper"  // "wallpaper" or "preset"
    property string preset: "default"
    property string wallpaper: ""
    property bool notifyWall: true     // wallpaper picker's "notify on wallpaper change"

    function reload() { pState.running = true }
    function apply(args) { run.run([[theme].concat(args)]) }
    function pretty(n) { return n.replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase()) }
    Component.onCompleted: { pState.running = true; pList.running = true; pNotify.running = true }
    Process {
        id: pNotify
        command: ["jq", "-r", "(.general // {}) | if has(\"notifyOnWallpaperChange\") then .notifyOnWallpaperChange else true end", page.home + "/.config/skwd-wall/config.json"]
        stdout: StdioCollector { onStreamFinished: page.notifyWall = text.trim() !== "false" }
    }
    function setNotify(on) {
        notifyWall = on
        run.run([["sh", "-c", "f=\"$HOME/.config/skwd-wall/config.json\"; jq --argjson v \"$1\" '.general.notifyOnWallpaperChange = $v' \"$f\" > \"$f.tmp\" && mv \"$f.tmp\" \"$f\"", "sh", on ? "true" : "false"]])
    }

    NmRun { id: run; onFinished: ok => page.reload() }
    Process {
        id: pState
        command: ["cat", (Quickshell.env("XDG_STATE_HOME") || (page.home + "/.local/state")) + "/43pr/state.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var s = JSON.parse(text)
                    page.colorGen = s.colorgen !== false
                    page.dark = s.mode_appearance !== "light"
                    page.mode = s.mode || "wallpaper"
                    page.preset = s.preset || "default"
                    page.wallpaper = s.wallpaper || ""
                } catch (e) {}
            }
        }
    }
    Process {
        id: pList
        command: [page.theme, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                text.split("\n").forEach(l => {
                    var m = l.trim().match(/^(\S+)\s+(.*)$/)
                    if (m) out.push({ name: m[1], desc: m[2] })
                })
                page.presets = out
            }
        }
    }

    SetSection { text: "Colours" }
    SetRow {
        label: "Colours from the wallpaper"
        hint: "The whole desktop takes its colours from your wallpaper. Turn off to keep a preset"
        wrapHint: true
        SetToggle { checked: page.colorGen; onToggled: v => { page.colorGen = v; page.apply(["colorgen", v ? "on" : "off"]) } }
    }
    SetRow {
        label: "Light or dark"
        SetSeg {
            options: ["Dark", "Light"]
            current: page.dark ? "Dark" : "Light"
            onPicked: v => { page.dark = v === "Dark"; page.apply(["mode", v.toLowerCase()]) }
        }
    }
    SetRow {
        label: "Preset"
        hint: page.mode === "preset" ? "" : "Using wallpaper colours. Pick one to switch to it"
        SetSelect {
            implicitWidth: 240
            listWidth: 360
            placeholder: "Wallpaper colours"
            options: page.presets.map(p => page.pretty(p.name) + "  ·  " + p.desc)
            currentIndex: page.mode === "preset" ? page.presets.findIndex(p => p.name === page.preset) : -1
            onPicked: i => { var n = page.presets[i].name; page.apply(n === "default" ? ["default"] : ["preset", n]) }
        }
        SetButton { visible: page.mode === "preset"; label: "Use wallpaper"; onClicked: page.apply(["auto"]) }
    }

    SetSection { text: "Wallpaper" }
    SetRow {
        label: "Wallpaper"
        hint: page.wallpaper !== "" ? page.wallpaper.split("/").pop() : "None chosen yet"
        SetButton { label: "Choose"; primary: true; onClicked: Quickshell.execDetached([page.home + "/.config/hypr/scripts/wallpaper-picker.sh"]) }
    }
    SetRow {
        label: "Notify when it changes"
        hint: "A notification each time a new wallpaper is set"
        SetToggle { checked: page.notifyWall; onToggled: v => page.setNotify(v) }
    }
}
