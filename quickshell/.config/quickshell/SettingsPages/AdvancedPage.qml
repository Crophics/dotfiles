import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Backup and restore your settings, reset them, and open the underlying config files.
SetPage {
    id: page
    title: "ADVANCED"

    readonly property string home: Quickshell.env("HOME")
    readonly property string hyprScripts: home + "/.config/hypr/scripts"
    property string message: ""
    property bool confirmReset: false
    property string backupPath: home + "/Documents/settings-backup-" + Qt.formatDate(new Date(), "yyyy-MM-dd") + ".tar.gz"
    property string importPath: ""

    NmRun {
        id: run
        onFinished: ok => page.message = ok ? "Done" : run.error
    }
    Timer { id: confirmTimer; interval: 4000; onTriggered: page.confirmReset = false }

    function edit(path) {
        Quickshell.execDetached(["sh", "-c", "command -v codium >/dev/null && exec codium \"$1\" || exec xdg-open \"$1\"", "sh", path.replace(/^~/, home)])
    }

    Text {
        visible: page.message !== ""
        width: parent.width
        wrapMode: Text.WordWrap
        text: page.message
        color: page.message === "Done" ? Theme.textDim : Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    SetSection { text: "Backup" }
    SetRow {
        label: "Save a backup"
        hint: page.backupPath
        SetButton { label: "Save"; primary: true; onClicked: run.run([[page.hyprScripts + "/settings-backup.sh", "export", page.backupPath]]) }
    }
    SetRow {
        label: "Restore a backup"
        hint: "Your current settings are kept as a safety copy first"
        SetTextField { implicitWidth: 260; placeholder: "~/Documents/settings-backup.tar.gz"; text: page.importPath; onEdited: v => page.importPath = v }
        SetButton {
            label: "Restore"; enabled: page.importPath !== ""
            onClicked: run.run([[page.hyprScripts + "/settings-backup.sh", "import", page.importPath.replace(/^~/, page.home)]])
        }
    }

    SetSection { text: "Reset" }
    SetRow {
        label: "Reset window and input settings"
        hint: "Puts every option on the Windows, Input, Layout and Behavior pages back to its default"
        SetButton {
            label: page.confirmReset ? "Click again to confirm" : "Reset"
            onClicked: {
                if (!page.confirmReset) { page.confirmReset = true; confirmTimer.restart(); return }
                page.confirmReset = false
                run.run([[page.hyprScripts + "/options.py", "reset-all"]])
            }
        }
    }
    SetRow {
        label: "Restart the shell"
        hint: "Reloads the bar, popups and this window. Fixes most display glitches"
        SetButton { label: "Restart"; onClicked: Quickshell.execDetached(["sh", "-c", "pkill -x qs; sleep 1; exec qs -d"]) }
    }

    SetSection { text: "Config files" }
    Repeater {
        model: [
            { label: "Hyprland", path: "~/.config/hypr/hyprland.lua", hint: "Autostart, environment, general setup" },
            { label: "Appearance", path: "~/.config/hypr/look.lua", hint: "Animations and colours" },
            { label: "Window rules", path: "~/.config/hypr/rules.lua", hint: "Per-app behaviour" },
            { label: "Lock screen", path: "~/.config/hypr/hyprlock.conf", hint: "" },
            { label: "Launcher", path: "~/.config/rofi/config.rasi", hint: "" },
            { label: "Shell theme", path: "~/.config/quickshell/Theme.qml", hint: "Fonts, sizes and animation timing for the bar and popups" }
        ]
        delegate: SetRow {
            required property var modelData
            label: modelData.label
            hint: modelData.hint !== "" ? modelData.hint : modelData.path
            SetButton { label: "Open"; onClicked: page.edit(modelData.path) }
        }
    }
    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Most of what is in these files can be changed from the other pages. Edit them only if you know what you are after. Settings changes are saved separately, so they survive edits here."
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
}
