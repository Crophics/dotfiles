import QtQuick
import "../"

// One registry option drawn as a SetRow with the matching control. Shows a reset button
// while the value differs from the default.
SetRow {
    id: r
    property var opt: ({})
    property var value: undefined          // current value, already resolved against the default
    property bool dirty: false
    signal moved(var v)                    // while dragging a slider
    signal changed(var v)                  // final value
    signal reset()

    label: opt.label || ""
    hint: opt.hint || ""
    wrapHint: true

    function labelFor(v) {
        var i = (opt.values || []).findIndex(x => x === v)
        return i >= 0 ? opt.options[i] : ""
    }

    SetButton { visible: r.dirty; label: "Reset"; onClicked: r.reset() }

    SetSlider {
        visible: r.opt.type === "slider"
        from: r.opt.min ?? 0; to: r.opt.max ?? 1; step: r.opt.step ?? 1
        unit: r.opt.unit || ""
        decimals: r.opt.decimals ?? 0
        displayText: r.opt.percent ? Math.round(value * 100) + "%" : value.toFixed(decimals) + unit
        value: Number(r.value ?? 0)
        onMoved: v => r.moved(v)
        onCommitted: v => r.changed(v)
    }
    SetToggle {
        visible: r.opt.type === "toggle"
        checked: r.value === true
        onToggled: v => r.changed(v)
    }
    readonly property bool longList: (opt.options || []).length > 4
    SetSelect {
        visible: r.opt.type === "seg" && r.longList
        implicitWidth: 160
        options: r.opt.options || []
        currentIndex: (r.opt.values || []).findIndex(x => x === r.value)
        onPicked: i => r.changed(r.opt.values[i])
    }
    SetSeg {
        visible: r.opt.type === "seg" && !r.longList
        options: r.opt.options || []
        current: r.labelFor(r.value)
        onPicked: v => r.changed(r.opt.values[r.opt.options.indexOf(v)])
    }
    SetTextField {
        visible: r.opt.type === "text"
        implicitWidth: 180
        placeholder: r.opt.placeholder || ""
        text: String(r.value ?? "")
        onEdited: v => commit.restart()
        Timer { id: commit; interval: 700; onTriggered: if (parent.text !== "") r.changed(parent.text) }
    }
}
