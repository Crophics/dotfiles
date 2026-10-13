import QtQuick
import "../"

// Everything about the top bar. Reads and writes the live bar (Refs.bar), so changes
// apply instantly and are saved by the bar itself.
SetPage {
    id: page
    title: "BAR"

    readonly property var bar: Refs.bar
    readonly property var cfg: bar ? bar.config : null

    SetSection { text: "Layout" }
    SetRow {
        label: "Position"
        SetSeg { options: page.bar ? page.bar.positions : []; current: page.cfg?.position ?? ""; onPicked: v => page.cfg.position = v }
    }
    SetRow {
        label: "Style"
        SetSeg { options: page.bar ? page.bar.styles : []; current: page.cfg?.style ?? ""; onPicked: v => page.cfg.style = v }
    }
    SetRow {
        label: "CPU / RAM"
        hint: "Compact fits a vertical bar"
        SetSeg { options: page.bar ? page.bar.statsModes : []; current: page.cfg?.statsMode ?? ""; onPicked: v => page.cfg.statsMode = v }
    }

    SetSection { text: "Size" }
    SetRow {
        label: "Thickness"
        SetSlider { from: 16; to: 40; step: 1; unit: " px"; value: page.cfg?.thickness ?? 20; onMoved: v => page.cfg.thickness = v }
    }
    SetRow {
        label: "Edge margin"
        hint: page.bar && page.bar.strip ? "Not used by the strip style" : ""
        enabled: !(page.bar && page.bar.strip)
        SetSlider { from: 0; to: 16; step: 1; unit: " px"; value: page.cfg?.margin ?? 4; onMoved: v => page.cfg.margin = v }
    }
    SetRow {
        label: "Text scale"
        SetSlider { from: 0.8; to: 1.5; step: 0.05; decimals: 2; unit: "x"; value: page.cfg?.scale ?? 1; onMoved: v => page.cfg.scale = v }
    }

    SetSection { text: "Look" }
    SetRow {
        label: "Background"
        SetSlider {
            from: 0; to: 1; step: 0.05
            value: page.cfg?.bgOpacity ?? 1
            displayText: Math.round(value * 100) + "%"
            onMoved: v => page.cfg.bgOpacity = v
        }
    }
    SetRow {
        label: "Border"
        SetToggle { checked: page.cfg?.border ?? false; onToggled: v => page.cfg.border = v }
    }
    SetRow {
        label: "Tooltips"
        SetToggle { checked: page.cfg?.tooltips ?? true; onToggled: v => page.cfg.tooltips = v }
    }
    SetRow {
        label: "Hints in tooltips"
        hint: "The \"Left click: ...\" lines"
        enabled: page.cfg?.tooltips ?? true
        SetToggle { checked: page.cfg?.tooltipHints ?? true; onToggled: v => page.cfg.tooltipHints = v }
    }

    SetSection { text: "Modules" }
    Repeater {
        model: page.bar ? page.bar.moduleDefs : []
        delegate: SetRow {
            required property var modelData
            label: modelData.l
            hint: modelData.fixed ? "Always shown" : ""

            SetToggle {
                enabled: !modelData.fixed
                opacity: enabled ? 1 : 0.4
                checked: !!modelData.fixed || page.bar.isOn(modelData.id)
                onToggled: v => page.bar.setOn(modelData.id, v)
            }
            SetSeg {
                options: page.bar.sections
                current: page.bar.sectionOf(modelData.id)
                onPicked: v => page.bar.moveTo(modelData.id, v)
            }
            SetButton {
                label: page.bar.vertical ? "▲" : "◀"
                enabled: page.bar.canShift(modelData.id, -1)
                onClicked: page.bar.shiftBy(modelData.id, -1)
            }
            SetButton {
                label: page.bar.vertical ? "▼" : "▶"
                enabled: page.bar.canShift(modelData.id, 1)
                onClicked: page.bar.shiftBy(modelData.id, 1)
            }
        }
    }

    Item { width: 1; height: 6 }
    SetButton { label: "Reset bar settings"; onClicked: page.bar.resetSettings() }
}
