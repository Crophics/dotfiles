import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Rebind the shortcuts, or add your own. The defaults come from hypr/keybind-defaults.json;
// your changes are saved to state/keybinds.json, and scripts/apply-keybinds.sh merges the two into
// the bindings Hyprland loads. While a new combo is being recorded Hyprland switches to the
// "capture" submap, so pressing an already-bound combo does not run its action.
SetPage {
    id: page
    title: "KEYBINDS"

    readonly property string home: Quickshell.env("HOME")
    property var defaults: []
    property var user: ({ overrides: {}, custom: [] })

    // Recording: id of the row being recorded ("" = none) and the last message to show.
    property string capturing: ""
    property string message: ""

    // Combos that are always bound and not editable here (zoom, mouse, media keys).
    readonly property var fixedCombos: ["SUPER+MINUS", "SUPER+EQUAL"]

    FileView {
        id: defaultsFile
        path: page.home + "/.config/hypr/keybind-defaults.json"
        printErrors: false
        onLoaded: { try { page.defaults = JSON.parse(defaultsFile.text()) } catch (e) { console.warn("keybinds: bad defaults:", e) } }
    }
    FileView {
        id: userFile
        path: page.home + "/.config/quickshell/state/keybinds.json"
        printErrors: false
        onLoaded: {
            try {
                var u = JSON.parse(userFile.text())
                page.user = { overrides: u.overrides || {}, custom: u.custom || [] }
            } catch (e) { console.warn("keybinds: bad saved state:", e) }
        }
        onSaved: Quickshell.execDetached([page.home + "/.config/hypr/scripts/apply-keybinds.sh"])
    }

    // Defaults merged with your changes, plus your custom shortcuts.
    readonly property var rows: {
        var out = []
        for (var i = 0; i < defaults.length; i++) {
            var d = defaults[i], o = user.overrides[d.id]
            out.push({
                id: d.id, group: d.group, label: d.label, modsOnly: !!d.modsOnly, custom: false,
                mods: o && o.mods !== undefined ? o.mods : d.mods,
                key: o && o.key !== undefined ? o.key : d.key,
                enabled: o && o.enabled !== undefined ? o.enabled : true,
                changed: !!o
            })
        }
        for (var j = 0; j < user.custom.length; j++) {
            var c = user.custom[j]
            out.push({ id: c.id, group: "Custom shortcuts", label: c.label, command: c.command, modsOnly: false, custom: true,
                       mods: c.mods || [], key: c.key || "", enabled: c.enabled !== false, changed: false })
        }
        return out
    }
    readonly property var groups: {
        var g = []
        for (var i = 0; i < rows.length; i++) if (g.indexOf(rows[i].group) < 0) g.push(rows[i].group)
        return g
    }

    function save() {
        userFile.setText(JSON.stringify(page.user, null, 1))
    }
    function mutate(fn) {
        var u = JSON.parse(JSON.stringify(page.user))
        fn(u)
        page.user = u
        save()
    }
    function setOverride(id, patch) {
        mutate(function (u) {
            var cur = u.overrides[id] || {}
            for (var k in patch) cur[k] = patch[k]
            u.overrides[id] = cur
        })
    }
    function resetRow(id) { mutate(function (u) { delete u.overrides[id] }) }
    function setRow(row, patch) {
        if (row.custom) mutate(function (u) {
            for (var i = 0; i < u.custom.length; i++)
                if (u.custom[i].id === row.id) for (var k in patch) u.custom[i][k] = patch[k]
        })
        else setOverride(row.id, patch)
    }
    function deleteCustom(id) { mutate(function (u) { u.custom = u.custom.filter(function (c) { return c.id !== id }) }) }

    // "SUPER+SHIFT+L", sorted, for comparing two bindings.
    function canon(mods, key) { return mods.slice().sort().concat([String(key).toUpperCase()]).join("+") }
    function conflictFor(id, mods, key) {
        var want = canon(mods, key)
        if (page.fixedCombos.indexOf(want) >= 0) return "a fixed shortcut (zoom)"
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i]
            if (r.id === id || !r.enabled || r.modsOnly || r.key === "") continue
            if (canon(r.mods, r.key) === want) return r.label
        }
        return ""
    }

    // ── Recording ──
    function startCapture(id) {
        page.capturing = id
        page.message = ""
        // Pause every shortcut while recording. The timer is a safety net that always ends it.
        Quickshell.execDetached(["sh", "-c",
            "hyprctl dispatch 'hl.dsp.submap(\"capture\")' >/dev/null; sleep 15; hyprctl dispatch 'hl.dsp.submap(\"reset\")' >/dev/null"])
        capturer.forceActiveFocus()
        stopTimer.restart()
    }
    function stopCapture() {
        page.capturing = ""
        stopTimer.stop()
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"])
    }
    Timer { id: stopTimer; interval: 15000; onTriggered: page.stopCapture() }
    Component.onDestruction: if (page.capturing !== "") Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"])

    // Qt key -> Hyprland key name ("" for modifiers and anything unsupported).
    readonly property var shiftedToBase: ({
        [Qt.Key_Exclam]: "1", [Qt.Key_At]: "2", [Qt.Key_NumberSign]: "3", [Qt.Key_Dollar]: "4", [Qt.Key_Percent]: "5",
        [Qt.Key_AsciiCircum]: "6", [Qt.Key_Ampersand]: "7", [Qt.Key_Asterisk]: "8", [Qt.Key_ParenLeft]: "9", [Qt.Key_ParenRight]: "0",
        [Qt.Key_Underscore]: "Minus", [Qt.Key_Plus]: "Equal", [Qt.Key_AsciiTilde]: "Grave", [Qt.Key_BraceLeft]: "bracketleft",
        [Qt.Key_BraceRight]: "bracketright", [Qt.Key_Bar]: "backslash", [Qt.Key_Colon]: "semicolon", [Qt.Key_QuoteDbl]: "apostrophe",
        [Qt.Key_Less]: "comma", [Qt.Key_Greater]: "period", [Qt.Key_Question]: "slash"
    })
    readonly property var namedKeys: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Escape]: "Escape", [Qt.Key_Space]: "Space", [Qt.Key_Tab]: "Tab",
        [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
        [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up",
        [Qt.Key_Down]: "Down", [Qt.Key_Print]: "Print", [Qt.Key_QuoteLeft]: "Grave", [Qt.Key_Minus]: "Minus", [Qt.Key_Equal]: "Equal",
        [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright", [Qt.Key_Backslash]: "backslash",
        [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period",
        [Qt.Key_Slash]: "slash"
    })
    function keyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1)
        if (namedKeys[k] !== undefined) return namedKeys[k]
        if (shiftedToBase[k] !== undefined) return shiftedToBase[k]
        return ""
    }
    function modsOf(m) {
        var out = []
        if (m & Qt.MetaModifier) out.push("SUPER")
        if (m & Qt.ControlModifier) out.push("CTRL")
        if (m & Qt.AltModifier) out.push("ALT")
        if (m & Qt.ShiftModifier) out.push("SHIFT")
        return out
    }

    Item {
        id: capturer
        width: 0; height: 0
        Keys.onPressed: event => {
            event.accepted = true
            if (page.capturing === "") return
            if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) { page.stopCapture(); page.message = "Cancelled"; return }
            var key = page.keyName(event.key)
            if (key === "") return                       // a modifier on its own, or a key we cannot bind
            var row = page.rows.find(function (r) { return r.id === page.capturing })
            if (!row) { page.stopCapture(); return }
            var mods = page.modsOf(event.modifiers)
            if (row.modsOnly) {
                if (mods.length === 0) { page.message = "Hold at least one modifier (Super, Ctrl, Alt or Shift) and press a number"; return }
                page.setRow(row, { mods: mods })
                page.message = row.label + ": " + mods.join(" + ") + " + 1 to 0"
            } else {
                var clash = page.conflictFor(row.id, mods, key)
                if (clash !== "") { page.message = mods.concat([key]).join(" + ") + " is already used by " + clash; return }
                page.setRow(row, { mods: mods, key: key })
                page.message = row.label + ": " + mods.concat([key]).join(" + ")
            }
            page.stopCapture()
        }
        onActiveFocusChanged: if (!activeFocus && page.capturing !== "") page.stopCapture()
    }

    // ── Add a custom shortcut ──
    property string newName: ""
    property string newCommand: ""
    function addCustom() {
        if (newName.trim() === "" || newCommand.trim() === "") { page.message = "Give the shortcut a name and a command first"; return }
        var id = "custom-" + Date.now()
        mutate(function (u) { u.custom.push({ id: id, label: newName.trim(), command: newCommand.trim(), mods: [], key: "", enabled: true }) })
        page.newName = ""; page.newCommand = ""
        nameField.text = ""; commandField.text = ""
        page.message = ""
        Qt.callLater(function () { page.startCapture(id) })
    }

    // ── The list ──
    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: page.capturing !== ""
              ? "Press the new keys now. Esc cancels."
              : (page.message !== "" ? page.message : "Click Change, then press the keys you want.")
        color: page.capturing !== "" ? Theme.accent : Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        topPadding: 2
        bottomPadding: 2
    }

    Repeater {
        model: page.groups
        delegate: Column {
            id: grp
            required property string modelData
            width: parent.width
            spacing: 6

            SetSection { text: grp.modelData }

            Repeater {
                model: page.rows.filter(function (r) { return r.group === grp.modelData })
                delegate: SetRow {
                    id: row
                    required property var modelData
                    readonly property bool recording: page.capturing === modelData.id
                    label: modelData.label
                    hint: modelData.custom ? modelData.command : (modelData.modsOnly ? "Choose the modifiers, the number row stays" : "")
                    color: recording ? Theme.alpha(Theme.accent, 0.10) : "transparent"
                    border.color: recording ? Theme.accent : Theme.border

                    KeyChips {
                        mods: modelData.mods
                        key: modelData.modsOnly ? "1 – 0" : modelData.key
                        dim: !modelData.enabled
                        visible: !row.recording
                    }
                    Text {
                        visible: row.recording
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                        text: "PRESS KEYS…"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1.5
                    }
                    SetButton {
                        label: row.recording ? "Cancel" : "Change"
                        primary: row.recording
                        onClicked: row.recording ? page.stopCapture() : page.startCapture(modelData.id)
                    }
                    SetButton {
                        visible: !modelData.custom
                        label: "Reset"
                        enabled: modelData.changed
                        onClicked: page.resetRow(modelData.id)
                    }
                    SetButton {
                        visible: modelData.custom
                        label: "Delete"
                        onClicked: page.deleteCustom(modelData.id)
                    }
                    SetToggle {
                        checked: modelData.enabled
                        onToggled: v => page.setRow(modelData, { enabled: v })
                    }
                }
            }
        }
    }

    SetSection { text: "Add a shortcut" }
    SetRow {
        label: "Name"
        SetTextField { id: nameField; placeholder: "e.g. Screenshot to file"; onEdited: v => page.newName = v }
    }
    SetRow {
        label: "Command"
        hint: "Runs in a shell, like a command typed in the terminal"
        SetTextField { id: commandField; implicitWidth: 300; placeholder: "e.g. grim ~/shot.png"; onEdited: v => page.newCommand = v }
    }
    SetRow {
        label: "Record the keys"
        hint: "Adds the shortcut, then listens for the keys"
        SetButton { label: "Add and set keys"; primary: true; onClicked: page.addCustom() }
    }

    Item { width: 1; height: 6 }
    SetButton {
        label: "Reset all keybinds"
        onClicked: { page.mutate(function (u) { u.overrides = {} }); page.message = "Defaults restored (custom shortcuts kept)" }
    }
}
