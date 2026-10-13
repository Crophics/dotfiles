import QtQuick
import "../"

// The on-screen popups: volume, brightness and the power menu. Each setting writes to
// the live component, which saves it, so the next popup already uses the new value.
SetPage {
    id: page
    title: "POPUPS"

    readonly property var vol: Refs.volumeOsd ? Refs.volumeOsd.osd : null
    readonly property var bri: Refs.brightnessOsd
    readonly property var pm: Refs.powerMenu
    readonly property var nt: Refs.notifications

    function seconds(ms) { return (ms / 1000).toFixed(1) + " s" }

    // ── Volume ──
    SetSection { text: "Volume popup" }
    SetRow {
        label: "Size"
        SetSlider {
            from: 70; to: 160; step: 10; unit: "%"
            value: page.vol?.osdScale ?? 100
            onMoved: v => { page.vol.setNumber("osdScale", v); page.vol.saveState() }
        }
    }
    SetRow {
        label: "Width"
        SetSlider {
            from: 200; to: 500; step: 20; unit: " px"
            value: page.vol?.flyoutWidth ?? 320
            onMoved: v => { page.vol.setNumber("flyoutWidth", v); page.vol.saveState() }
        }
    }
    SetRow {
        label: "Hide after"
        SetSlider {
            from: 600; to: 5000; step: 200
            value: page.vol?.volTimeout ?? 1200
            displayText: page.seconds(value)
            onMoved: v => { page.vol.setNumber("volTimeout", v); page.vol.saveState() }
        }
    }
    SetRow {
        label: "Position"
        hint: "Hover the popup and drag the handle under it to move it"
        SetButton { label: "Reset position"; enabled: page.vol?.volumeMoved ?? false; onClicked: page.vol.resetPos() }
        SetButton { label: "Preview"; onClicked: page.vol.triggerOsd() }
    }

    // ── Brightness ──
    SetSection { text: "Brightness popup" }
    SetRow {
        label: "Step"
        hint: "Brightness change per key press"
        SetSlider {
            from: 1; to: 20; step: 1; unit: "%"
            value: page.bri?.step ?? 5
            onMoved: v => { page.bri.step = v; page.bri.saveState() }
        }
    }
    SetRow {
        label: "Hide after"
        SetSlider {
            from: 600; to: 5000; step: 200
            value: page.bri?.timeout ?? 1200
            displayText: page.seconds(value)
            onMoved: v => { page.bri.timeout = v; page.bri.saveState() }
        }
    }
    SetRow {
        label: "Preview"
        SetButton { label: "Show popup"; onClicked: page.bri.refresh() }
    }

    // ── Notifications ──
    SetSection { text: "Notifications" }
    SetRow {
        label: "Do Not Disturb"
        hint: "Hides notification popups. Critical ones still show. Right-click the bell in the bar does the same"
        wrapHint: true
        SetToggle {
            checked: page.nt?.dnd ?? false
            onToggled: v => { if (page.nt && v !== page.nt.dnd) page.nt.toggleDnd() }
        }
    }

    // ── Power menu ──
    SetSection { text: "Power menu" }
    SetRow {
        label: "Layout"
        SetSeg {
            options: ["vertical", "horizontal"]
            current: page.pm?.horizontal ? "horizontal" : "vertical"
            onPicked: v => { page.pm.horizontal = (v === "horizontal"); page.pm.saveState() }
        }
    }
    SetRow {
        label: "Size"
        SetSlider {
            from: 70; to: 160; step: 10; unit: "%"
            value: page.pm?.menuSize ?? 100
            onMoved: v => { page.pm.setMenuSize(v); page.pm.saveState() }
        }
    }
    SetRow {
        label: "Width"
        SetSlider {
            from: 200; to: 500; step: 10; unit: " px"
            value: page.pm?.cardWidth ?? 284
            onMoved: v => { page.pm.cardWidth = v; page.pm.saveState() }
        }
    }
    SetRow {
        label: "Row height"
        SetSlider {
            from: 40; to: 100; step: 4; unit: " px"
            value: page.pm?.itemHeight ?? 56
            onMoved: v => { page.pm.itemHeight = v; page.pm.saveState() }
        }
    }
    SetRow {
        label: "Spacing"
        SetSlider {
            from: 0; to: 24; step: 2; unit: " px"
            value: page.pm?.itemSpacing ?? 8
            onMoved: v => { page.pm.itemSpacing = v; page.pm.saveState() }
        }
    }

    SetSection { text: "Power menu actions" }
    Repeater {
        model: page.pm ? page.pm.actions : []
        delegate: SetRow {
            required property var modelData
            readonly property bool shown: page.pm.hiddenNames.indexOf(modelData.name) < 0
            label: modelData.label
            hint: "Key: " + modelData.key.toUpperCase()
            SetToggle {
                checked: parent.parent.shown
                enabled: !checked || page.pm.visibleActions.length > 1
                opacity: enabled ? 1 : 0.4
                onToggled: page.pm.toggleAction(modelData.name)
            }
        }
    }

    Item { width: 1; height: 6 }
    Row {
        spacing: 8
        SetButton { label: "Reset volume popup"; onClicked: page.vol.resetAll() }
        SetButton { label: "Reset power menu"; onClicked: page.pm.resetPosition() }
        SetButton { label: "Preview power menu"; onClicked: page.pm.openMenu() }
    }
}
