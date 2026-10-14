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
    readonly property string nightScript: home + "/.config/hypr/scripts/nightlight.py"

    property var cfg: []                 // one entry per monitor, what the user is editing
    property int countdown: 0            // seconds left to confirm, 0 = nothing pending
    property real brightness: 0.6
    property bool hasBacklight: false
    property bool nightOn: false
    property int nightTemp: 4500
    property bool nightAuto: false
    property bool nightDrag: false      // slider is being dragged: keep its value, ignore status refreshes
    property string nightStart: "20:00"
    property string nightEnd: "07:00"

    readonly property var rotations: ["Normal", "90°", "180°", "270°"]
    readonly property var vrrNames: ["Off", "On", "Fullscreen only"]

    function uniq(arr) { return arr.filter((v, i) => arr.indexOf(v) === i) }
    function resolutions(c) { return uniq(c.modes.map(m => m.res)) }
    function rates(c, res) { return c.modes.filter(m => m.res === res).map(m => m.rate) }
    function rateLabel(r) { return parseFloat(r).toFixed(0) + " Hz" }
    // Every scale Hyprland can use on this screen: a multiple of 1/120 that divides both sides
    // of the picture exactly. Returned as percentages with decimals, like 106.67.
    function scales(c) {
        var w = parseInt(c.res.split("x")[0]), h = parseInt(c.res.split("x")[1]), out = []
        for (var k = 90; k <= 360; k++) {
            if ((w * 120) % k === 0 && (h * 120) % k === 0) out.push(k * 100 / 120)
        }
        return out
    }
    function scaleLabel(p) { return Math.round(p) + "%" }
    function scaleNear(c) {
        var list = scales(c), best = list[0] || 100, want = c.scale * 100
        list.forEach(p => { if (Math.abs(p - want) < Math.abs(best - want)) best = p })
        return best
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
        command: [nightScript, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    page.nightOn = d.on === true
                    if (!page.nightDrag && !nightSet.running && !page.nightQueue) page.nightTemp = d.temp
                    page.nightAuto = d.auto === true; page.nightStart = d.start; page.nightEnd = d.end
                } catch (e) {}
            }
        }
    }
    // Night light commands run one at a time; while a slider drags, only the newest preview waits.
    property var nightQueue: null
    Process {
        id: nightSet
        onExited: {
            if (page.nightQueue) { var c = page.nightQueue; page.nightQueue = null; nightSet.command = c; nightSet.running = true }
            else pNight.running = true
        }
    }
    function night(args) {
        var cmd = [nightScript].concat(args)
        if (nightSet.running) { nightQueue = cmd; return }
        nightSet.command = cmd
        nightSet.running = true
    }
    function addMinutes(t, d) {
        var m = ((parseInt(t.split(":")[0]) * 60 + parseInt(t.split(":")[1]) + d) % 1440 + 1440) % 1440
        return ("0" + Math.floor(m / 60)).slice(-2) + ":" + ("0" + (m % 60)).slice(-2)
    }
    readonly property var timeRe: /^([01]?\d|2[0-3]):[0-5]\d$/

    // ── one block per monitor ──
    Repeater {
        model: page.cfg
        delegate: Column {
            id: mon
            required property var modelData
            width: parent ? parent.width : 0
            spacing: 10
            property bool popupOpen: false    // set by a dropdown inside: draw this whole block above what follows
            z: popupOpen ? 100 : 0
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
                SetSelect {
                    implicitWidth: 180
                    options: page.resolutions(modelData)
                    currentIndex: page.resolutions(modelData).indexOf(modelData.res)
                    onPicked: i => {
                        var v = page.resolutions(modelData)[i]
                        var r = page.rates(modelData, v)
                        var rate = r.indexOf(modelData.rate) >= 0 ? modelData.rate : r.slice().sort((a, b) => b - a)[0]
                        var next = Object.assign({}, modelData, { res: v })
                        page.edit(modelData.name, { res: v, rate: rate, scale: page.scaleNear(next) / 100 })
                    }
                }
            }
            SetRow {
                visible: modelData.enabled
                label: "Refresh rate"
                SetSelect {
                    implicitWidth: 140
                    options: page.rates(modelData, modelData.res).map(page.rateLabel)
                    currentIndex: page.rates(modelData, modelData.res).indexOf(modelData.rate)
                    onPicked: i => page.edit(modelData.name, { rate: page.rates(modelData, modelData.res)[i] })
                }
            }
            SetRow {
                visible: modelData.enabled
                label: "Scale"
                hint: "Larger makes everything bigger. Every size this screen can show exactly"
                wrapHint: true
                SetSelect {
                    implicitWidth: 140
                    options: page.scales(modelData).map(page.scaleLabel)
                    currentIndex: page.scales(modelData).indexOf(page.scaleNear(modelData))
                    onPicked: i => page.edit(modelData.name, { scale: page.scales(modelData)[i] / 100 })
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
        hint: page.nightAuto ? "With a schedule on, this holds until the next scheduled switch" : "Warmer colours for the evening"
        SetToggle { checked: page.nightOn; onToggled: v => { page.nightOn = v; page.night(["toggle", v ? "on" : "off"]) } }
    }
    SetRow {
        label: "Warmth"
        hint: "Lower is warmer"
        SetSlider {
            from: 2500; to: 6500; step: 100; unit: " K"
            value: page.nightTemp
            onMoved: v => { page.nightDrag = true; page.nightTemp = v; page.night(["temp", String(v), "preview"]) }
            onCommitted: v => { page.nightTemp = v; page.night(["temp", String(v)]); page.nightDrag = false }
        }
    }
    SetRow {
        label: "Schedule"
        hint: "Turn on and off at set times every day"
        SetToggle { checked: page.nightAuto; onToggled: v => { page.nightAuto = v; page.night(["auto", v ? "on" : "off"]) } }
    }
    SetRow {
        visible: page.nightAuto
        label: "Turn on at"
        SetButton { label: "−"; onClicked: { page.nightStart = page.addMinutes(page.nightStart, -30); page.night(["times", page.nightStart, page.nightEnd]) } }
        SetTextField {
            id: tStart; implicitWidth: 70; text: page.nightStart
            onEdited: v => startCommit.restart()
            Timer { id: startCommit; interval: 700; onTriggered: if (page.timeRe.test(tStart.text)) { page.nightStart = tStart.text; page.night(["times", page.nightStart, page.nightEnd]) } }
        }
        SetButton { label: "+"; onClicked: { page.nightStart = page.addMinutes(page.nightStart, 30); page.night(["times", page.nightStart, page.nightEnd]) } }
    }
    SetRow {
        visible: page.nightAuto
        label: "Turn off at"
        SetButton { label: "−"; onClicked: { page.nightEnd = page.addMinutes(page.nightEnd, -30); page.night(["times", page.nightStart, page.nightEnd]) } }
        SetTextField {
            id: tEnd; implicitWidth: 70; text: page.nightEnd
            onEdited: v => endCommit.restart()
            Timer { id: endCommit; interval: 700; onTriggered: if (page.timeRe.test(tEnd.text)) { page.nightEnd = tEnd.text; page.night(["times", page.nightStart, page.nightEnd]) } }
        }
        SetButton { label: "+"; onClicked: { page.nightEnd = page.addMinutes(page.nightEnd, 30); page.night(["times", page.nightStart, page.nightEnd]) } }
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
