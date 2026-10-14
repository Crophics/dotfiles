import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Monitors, brightness and night light. Monitor changes go through scripts/display.py and
// start a 15 second countdown: unless you press Keep, the old settings come back.
SetPage {
    id: page
    title: "DISPLAY"

    readonly property string home: Quickshell.env("HOME")
    readonly property string displayScript: home + "/.config/hypr/scripts/display.py"
    readonly property string nightScript: home + "/.config/hypr/scripts/nightlight.sh"

    property var cfg: []                 // one entry per monitor, what the user is editing
    property int countdown: 0            // seconds left to confirm, 0 = nothing pending
    property real brightness: 0.6
    property bool hasBacklight: false
    property bool nightOn: false
    property int nightTemp: 4500

    readonly property var rotations: ["Normal", "90°", "180°", "270°"]
    readonly property var vrrNames: ["Off", "On", "Fullscreen only"]

    function uniq(arr) { return arr.filter((v, i) => arr.indexOf(v) === i) }
    function resolutions(c) { return uniq(c.modes.map(m => m.res)) }
    function rates(c, res) { return c.modes.filter(m => m.res === res).map(m => m.rate) }
    function rateLabel(r) { return parseFloat(r).toFixed(0) + " Hz" }
    // Scales that give a whole-pixel desktop, shown as clean percentages.
    function scales(c) {
        var w = parseInt(c.res.split("x")[0]), h = parseInt(c.res.split("x")[1]), out = []
        for (var k = 60; k <= 360; k++) {
            if ((w * 120) % k === 0 && (h * 120) % k === 0 && (k * 100) % 120 === 0) out.push(k * 100 / 120)
        }
        return out.filter(p => p >= 75 && p <= 300)
    }
    function find(name) { return cfg.find(c => c.name === name) }
    function logicalSize(c) {
        var w = parseInt(c.res.split("x")[0]), h = parseInt(c.res.split("x")[1])
        if (c.transform % 2 === 1) { var t = w; w = h; h = t }
        return [Math.round(w / c.scale), Math.round(h / c.scale)]
    }
    function placeSide(c) {
        if (c.place.indexOf(":") > 0 && c.place.indexOf("at:") !== 0) return c.place.split(":")[0]
        var o = cfg.find(x => x.name !== c.name && x.enabled)
        if (!o || c.place.indexOf("at:") !== 0) return ""
        var p = c.place.slice(3).split("x").map(Number), q = o.place.slice(3).split("x").map(Number)
        var ow = logicalSize(o), cw = logicalSize(c)
        if (p[0] === q[0] + ow[0]) return "right-of"
        if (p[0] === q[0] - cw[0]) return "left-of"
        if (p[1] === q[1] - cw[1]) return "above"
        if (p[1] === q[1] + ow[1]) return "below"
        return ""
    }
    function placeTarget(c) {
        if (c.place.indexOf(":") > 0 && c.place.indexOf("at:") !== 0) return c.place.split(":")[1]
        var o = cfg.find(x => x.name !== c.name && x.enabled)
        return o ? o.name : ""
    }

    function edit(name, patch) {
        cfg = cfg.map(c => c.name === name ? Object.assign({}, c, patch) : c)
        send()
    }
    function send() {
        var list = cfg.map(c => ({ name: c.name, enabled: c.enabled, mode: c.res + "@" + c.rate, scale: c.scale,
                                   transform: c.transform, vrr: c.vrr, place: c.place }))
        run.run([[displayScript, "apply", JSON.stringify(list)]])
        countdown = 15
    }
    function keep() { countdown = 0; run.run([[displayScript, "keep"]]) }
    function revert() { countdown = 0; run.run([[displayScript, "revert"]]); reloadSoon.restart() }

    NmRun { id: run; onFinished: ok => reloadSoon.restart() }
    Timer { id: reloadSoon; interval: 700; onTriggered: pMon.running = true }
    Timer {
        interval: 1000; repeat: true; running: page.countdown > 0
        onTriggered: { page.countdown--; if (page.countdown === 0) page.revert() }
    }
    Component.onCompleted: { pMon.running = true; pBr.running = true; pNight.running = true }

    Process {
        id: pMon
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                try {
                    JSON.parse(text).forEach(m => {
                        var modes = (m.availableModes || []).map(s => {
                            var p = s.replace("Hz", "").split("@")
                            return { res: p[0], rate: p[1] }
                        })
                        var res = m.width + "x" + m.height
                        var near = modes.filter(x => x.res === res).sort((a, b) => Math.abs(a.rate - m.refreshRate) - Math.abs(b.rate - m.refreshRate))[0]
                        out.push({
                            name: m.name, desc: m.description, enabled: !m.disabled, modes: modes,
                            res: res, rate: near ? near.rate : m.refreshRate.toFixed(2),
                            scale: Math.round(m.scale * 10000) / 10000, transform: m.transform, vrr: m.vrr ? 1 : 0,
                            place: m.mirrorOf && m.mirrorOf !== "none" ? "mirror:" + m.mirrorOf : "at:" + m.x + "x" + m.y
                        })
                    })
                } catch (e) {}
                page.cfg = out
            }
        }
    }
    Process {
        id: pBr
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(",")
                if (p.length >= 4 && !isNaN(parseInt(p[3]))) { page.brightness = parseInt(p[3]) / 100; page.hasBacklight = true }
            }
        }
    }
    Process { id: brSet }
    Process {
        id: pNight
        command: ["sh", "-c", "cat \"$HOME/.config/quickshell/state/nightlight.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { var s = JSON.parse(text); page.nightOn = s.enabled === true; page.nightTemp = s.temp || 4500 } catch (e) {}
            }
        }
    }
    Process { id: nightSet }
    function setNight(on, temp) {
        nightOn = on; nightTemp = temp
        nightSet.command = [nightScript, "set", on ? "on" : "off", String(temp)]
        nightSet.running = true
    }

    // ── one block per monitor ──
    Repeater {
        model: page.cfg
        delegate: Column {
            id: mon
            required property var modelData
            width: parent ? parent.width : 0
            spacing: 10
            readonly property var others: page.cfg.filter(c => c.name !== modelData.name && c.enabled)

            SetSection { text: modelData.name + (modelData.desc ? "  ·  " + modelData.desc : "") }

            SetRow {
                visible: page.cfg.length > 1
                label: "Enabled"
                hint: "Turn this screen off. At least one has to stay on"
                SetToggle {
                    checked: modelData.enabled
                    onToggled: v => { if (v || mon.others.length > 0) page.edit(modelData.name, { enabled: v }) }
                }
            }
            SetRow {
                visible: modelData.enabled
                label: "Resolution"
                controlWidth: 430
                SetChips {
                    width: 430
                    options: page.resolutions(modelData)
                    current: modelData.res
                    onPicked: v => {
                        var r = page.rates(modelData, v)
                        var rate = r.indexOf(modelData.rate) >= 0 ? modelData.rate : r.slice().sort((a, b) => b - a)[0]
                        var sc = page.scales(Object.assign({}, modelData, { res: v }))
                        var scale = sc.indexOf(Math.round(modelData.scale * 100)) >= 0 ? modelData.scale : (sc.indexOf(100) >= 0 ? 1 : sc[0] / 100)
                        page.edit(modelData.name, { res: v, rate: rate, scale: scale })
                    }
                }
            }
            SetRow {
                visible: modelData.enabled && page.rates(modelData, modelData.res).length > 1
                label: "Refresh rate"
                SetSeg {
                    options: page.rates(modelData, modelData.res).map(page.rateLabel)
                    current: page.rateLabel(modelData.rate)
                    onPicked: v => page.edit(modelData.name, { rate: page.rates(modelData, modelData.res)[options.indexOf(v)] })
                }
            }
            SetRow {
                visible: modelData.enabled
                label: "Scale"
                hint: "Larger makes everything bigger. Only sizes that fit the screen exactly are listed"
                wrapHint: true
                controlWidth: 330
                SetChips {
                    width: 330
                    options: page.scales(modelData).map(p => p + "%")
                    current: Math.round(modelData.scale * 100) + "%"
                    onPicked: v => page.edit(modelData.name, { scale: parseInt(v) / 100 })
                }
            }
            SetRow {
                visible: modelData.enabled
                label: "Rotation"
                SetSeg {
                    options: page.rotations
                    current: page.rotations[modelData.transform % 4] || "Normal"
                    onPicked: v => page.edit(modelData.name, { transform: page.rotations.indexOf(v) })
                }
            }
            SetRow {
                visible: modelData.enabled
                label: "Variable refresh rate"
                hint: "Smoother games and video when the screen supports it"
                SetSeg {
                    options: page.vrrNames
                    current: page.vrrNames[modelData.vrr] || "Off"
                    onPicked: v => page.edit(modelData.name, { vrr: page.vrrNames.indexOf(v) })
                }
            }
            SetRow {
                visible: modelData.enabled && mon.others.length > 0
                label: "Position"
                hint: "Where this screen sits next to " + (page.placeTarget(modelData) || "the other one")
                controlWidth: 420
                SetChips {
                    width: 420
                    options: ["Right of", "Left of", "Above", "Below", "Mirror"]
                    current: ({ "right-of": "Right of", "left-of": "Left of", "above": "Above", "below": "Below", "mirror": "Mirror" })[page.placeSide(modelData)] || ""
                    onPicked: v => {
                        var side = ({ "Right of": "right-of", "Left of": "left-of", "Above": "above", "Below": "below", "Mirror": "mirror" })[v]
                        page.edit(modelData.name, { place: side + ":" + (page.placeTarget(modelData) || mon.others[0].name) })
                    }
                }
            }
            SetRow {
                visible: modelData.enabled && mon.others.length > 1
                label: "Relative to"
                SetSeg {
                    options: mon.others.map(c => c.name)
                    current: page.placeTarget(modelData)
                    onPicked: v => page.edit(modelData.name, { place: (page.placeSide(modelData) || "right-of") + ":" + v })
                }
            }
        }
    }

    // ── Brightness ──
    SetSection { text: "Brightness"; visible: page.hasBacklight }
    SetRow {
        visible: page.hasBacklight
        label: "Screen brightness"
        SetSlider {
            from: 0.05; to: 1; step: 0.01
            displayText: Math.round(value * 100) + "%"
            value: page.brightness
            onMoved: v => { page.brightness = v; brSet.command = ["brightnessctl", "set", Math.round(v * 100) + "%"]; if (!brSet.running) brSet.running = true }
            onCommitted: v => { brSet.command = ["brightnessctl", "set", Math.round(v * 100) + "%"]; brSet.running = true }
        }
    }

    // ── Night light ──
    SetSection { text: "Night light" }
    SetRow {
        label: "Night light"
        hint: "Warmer colours for the evening"
        SetToggle { checked: page.nightOn; onToggled: v => page.setNight(v, page.nightTemp) }
    }
    SetRow {
        label: "Warmth"
        hint: "Lower is warmer"
        enabled: page.nightOn
        SetSlider {
            from: 2500; to: 6500; step: 100; unit: " K"
            value: page.nightTemp
            onCommitted: v => page.setNight(true, v)
        }
    }

    // ── confirm bar ──
    Rectangle {
        parent: page
        visible: page.countdown > 0
        z: 60
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 45
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 54
        radius: Theme.radius
        color: Theme.bgPanel
        border.width: 1
        border.color: Theme.accent

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "KEEP THESE DISPLAY SETTINGS?  REVERTING IN " + page.countdown + " S"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            SetButton { label: "Revert"; onClicked: page.revert() }
            SetButton { label: "Keep"; primary: true; onClicked: page.keep() }
        }
    }
}
