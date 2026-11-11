import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Backup and restore the shell settings, restart the shell, and open the config files in nvim.
SetPage {
    id: page
    title: "ADVANCED"

    readonly property string home: Quickshell.env("HOME")
    readonly property string hyprScripts: home + "/.config/hypr/scripts"
    property string message: ""
    property string backupPath: home + "/Documents/settings-backup-" + Qt.formatDate(new Date(), "yyyy-MM-dd") + ".tar.gz"
    property string importPath: ""

    NmRun {
        id: run
        onFinished: ok => page.message = ok ? "Done" : run.error
    }

    function edit(path) {
        Quickshell.execDetached(["kitty", "nvim", path.replace(/^~/, home)])
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

    SetSection { text: "Shell" }
    SetRow {
        label: "Restart the shell"
        hint: "Reloads the bar, popups and this window. Fixes most display glitches"
        SetButton { label: "Restart"; onClicked: Quickshell.execDetached(["sh", "-c", "pkill -x qs; sleep 1; exec qs -d"]) }
    }

    SetSection { text: "Config files" }
    Repeater {
        model: [
            { label: "Hyprland", path: "~/.config/hypr/hyprland.lua", hint: "Programs, input, autostart, environment" },
            { label: "Keybinds", path: "~/.config/hypr/keybinds.lua", hint: "Every keyboard shortcut" },
            { label: "Decorations", path: "~/.config/hypr/decorations.lua", hint: "Borders, gaps, rounding, blur, animations" },
            { label: "Window rules", path: "~/.config/hypr/rules.lua", hint: "Per-app behaviour and window opacity" },
            { label: "Monitors", path: "~/.config/hypr/monitors.lua", hint: "Screen resolution and scale" },
            { label: "Lock screen", path: "~/.config/hypr/hyprlock.conf", hint: "How the lock screen looks (hyprlock)" },
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
        text: "These files are the real Hyprland config, with comments. Edit them directly (they open in nvim); Hyprland reloads when you save. See ~/.config/hypr/README.md."
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
}
