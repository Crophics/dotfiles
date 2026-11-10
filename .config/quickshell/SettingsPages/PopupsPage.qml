import QtQuick
import "../"

// The on-screen popups: volume, brightness and the power menu. Each setting writes to
// the live component, which saves it, so the next popup already uses the new value.
SetPage {
    id: page
    title: "POPUPS"

    readonly property var vol: Refs.volumeOsd ? Refs.volumeOsd.osd : null
    readonly property var bri: Refs.brightnessOsd

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

    Item { width: 1; height: 6 }
    Row {
        spacing: 8
        SetButton { label: "Reset volume popup"; onClicked: page.vol.resetAll() }
    }
}
