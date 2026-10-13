import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root

    // ───────────────────────── Config ─────────────────────────
    // Single source of truth for defaults (used by the adapter AND reset).
    readonly property var defaults: ({
        position: "top", style: "joined", thickness: 20, margin: 4,
        scale: 1.0, bgOpacity: 1.0, border: false,
        statsMode: "compact", showTemp: true, clockFormat: "ddd d MMM  HH:mm", tooltips: true, tooltipHints: true,
        hidden: "stats,wall,settings",
        startMods: "stats,ws",
        centerMods: "clock",
        endMods: "media,volume,battery,net,notif,wall,settings,power"
    })
    readonly property var positions: ["top", "right", "bottom", "left"]
    readonly property var styles: ["floating", "joined", "strip"]
    readonly property var sections: ["start", "center", "end"]
    readonly property var statsModes: ["default", "compact"]

    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        adapter: JsonAdapter {
            id: cfg
            property string position: root.defaults.position
            property string style: root.defaults.style
            property int thickness: root.defaults.thickness
            property int margin: root.defaults.margin
            property real scale: root.defaults.scale
            property real bgOpacity: root.defaults.bgOpacity
            property bool border: root.defaults.border
            property string statsMode: root.defaults.statsMode   // "default" | "compact"
            property string clockFormat: root.defaults.clockFormat   // Qt date/time format (Settings > Bar > Clock)
            property bool showTemp: root.defaults.showTemp       // CPU temperature next to CPU / RAM
            property bool tooltips: root.defaults.tooltips
            property bool tooltipHints: root.defaults.tooltipHints // show "Left click: ..." lines in tooltips
            property string hidden: root.defaults.hidden         // comma list of disabled modules
            property string startMods: root.defaults.startMods
            property string centerMods: root.defaults.centerMods
            property string endMods: root.defaults.endMods
        }
    }

    Timer { id: saveTimer; interval: 300; onTriggered: cfgFile.writeAdapter() }

    // The saved settings object, for the Settings app (SettingsPages/BarPage.qml).
    property var config: cfg

    function resetSettings() { for (const k in defaults) cfg[k] = defaults[k]; }

    // ───────────────────────── Derived layout ─────────────────────────
    readonly property bool vertical: cfg.position === "left" || cfg.position === "right"
    readonly property bool joined: cfg.style !== "floating"
    readonly property bool strip: cfg.style === "strip"
    readonly property int panelThick: vertical ? cfg.thickness + 12 : cfg.thickness
    readonly property int effEdge: strip ? 0 : cfg.margin
    readonly property int effGap: strip ? 0 : 6
    readonly property real barRadius: strip ? 0 : Theme.radius
    readonly property color bgColor: Qt.alpha(Theme._bgBase, cfg.bgOpacity * Theme.bgAlpha)
    readonly property color borderColor: Qt.alpha(Theme.accent, 0.25)

    function s(n) { return Math.round(n * cfg.scale); }

    readonly property var sz: ({
        stat: s(12), clock: s(12), marquee: s(11),
        icon: s(16), batIcon: s(13), batText: s(12), power: s(13),
        calTime: s(30), calDate: s(12), calMonth: s(13), calArrow: s(16),
        calWeekday: s(11), calDay: s(12)
    })
    readonly property int sizeIconGap: 12
    readonly property int iconYOffset: 1

    // margin for one side of the bar frame
    function edgeMargin(side) {
        if (cfg.position === side) return effEdge;
        const alongBar = vertical ? (side === "top" || side === "bottom")
                                  : (side === "left" || side === "right");
        return alongBar ? effGap : 0;
    }

    // ───────────────────────── Battery ─────────────────────────
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property int batPct: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge
            || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batLow: battery !== null && !batCharging && batPct <= 15
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

    function fmtTime(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property string batTip: {
        if (battery === null) return "";
        const t = batCharging ? battery.timeToFull : battery.timeToEmpty;
        const st = battery.state === UPowerDeviceState.FullyCharged ? "fully charged"
                 : batCharging ? "charging" : "on battery";
        return "Battery " + batPct + "% · " + st
            + (t > 0 ? " · " + fmtTime(t) + (batCharging ? " to full" : " left") : "");
    }

    // ───────────────────────── Module registry ─────────────────────────
    // Modules with `cmd` are rendered by the generic iconC component:
    //   g = glyph, tip = tooltip title, hint = left-click description.
    // Modules without it have a dedicated Component below (see `comps`).
    readonly property var moduleDefs: [
        { id: "stats",    l: "CPU / Temp / RAM" },
        { id: "ws",       l: "Workspaces" },
        { id: "media",    l: "Media" },
        { id: "volume",   l: "Volume" },
        { id: "battery",  l: "Battery" },
        { id: "net",      l: "Network",       cmd: "qs ipc call settings network",
                                              hint: "Open network settings" },
        { id: "notif",    l: "Notifications", cmd: "qs ipc call notifications toggle", g: "\uDB80\uDC9A",
                                              tip: "Notifications", hint: "Toggle notification panel" },
        { id: "wall",     l: "Wallpapers",    cmd: "qs -n -p ~/.config/quickshell/hyprquickpaper", g: "\uDB80\uDEE9",
                                              tip: "Wallpapers", hint: "Open wallpaper picker" },
        { id: "settings", l: "Settings",      cmd: "qs ipc call settings toggle", g: "\uDB81\uDC93",
                                              tip: "Settings", hint: "Open settings" },
        { id: "power",    l: "Power",         cmd: "qs ipc call powermenu toggle", g: "\u23FB",
                                              tip: "Power menu", hint: "Open", fixed: true }
    ]
    readonly property var moduleIds: moduleDefs.map(d => d.id)
    readonly property var defMap: moduleDefs.reduce((m, d) => { m[d.id] = d; return m; }, {})
    readonly property var comps: ({
        stats: statsC, ws: wsC, media: mediaC, volume: volumeC, battery: batteryC, icon: iconC
    })

    function csv(str) { return str === "" ? [] : str.split(","); }
    function valid(id) { return moduleIds.indexOf(id) >= 0; }

    // enable / disable
    readonly property var hiddenList: csv(cfg.hidden)
    function isOn(id) { return hiddenList.indexOf(id) < 0; }
    function setOn(id, on) {
        const h = hiddenList.filter(x => x !== id);
        if (!on) h.push(id);
        cfg.hidden = h.join(",");
    }

    function modVisible(id) {
        if (!isOn(id)) return false;
        switch (id) {
        case "stats":   return !vertical || cfg.statsMode === "compact";   // compact fits vertical bars
        case "media":   return Marquee.player !== null && Marquee.title !== "";
        case "battery": return battery !== null;
        default:        return true;
        }
    }

    // sections
    readonly property var startList: csv(cfg.startMods).filter(valid)
    readonly property var centerList: {
        const a = csv(cfg.centerMods).filter(x => x === "clock" || valid(x));
        return a.indexOf("clock") >= 0 ? a : ["clock"].concat(a);
    }
    readonly property var endList: {
        const a = csv(cfg.endMods).filter(valid);
        return a.concat(moduleIds.filter(x =>
            startList.indexOf(x) < 0 && centerList.indexOf(x) < 0 && a.indexOf(x) < 0));
    }

    function listOf(sec) { return (sec === "start" ? startList : sec === "center" ? centerList : endList).slice(); }
    function setList(sec, a) { cfg[sec + "Mods"] = a.join(","); }
    function sectionOf(id) { return sections.find(k => listOf(k).indexOf(id) >= 0) ?? "end"; }

    function moveTo(id, sec) {
        const next = {};
        for (const k of sections) next[k] = listOf(k).filter(x => x !== id);
        next[sec].push(id);
        for (const k of sections) setList(k, next[k]);
    }

    function canShift(id, d) {
        const a = listOf(sectionOf(id)), j = a.indexOf(id) + d;
        return j >= 0 && j < a.length;
    }

    function shiftBy(id, d) {
        if (!canShift(id, d)) return;
        const sec = sectionOf(id), a = listOf(sec), i = a.indexOf(id), j = i + d;
        [a[i], a[j]] = [a[j], a[i]];
        setList(sec, a);
    }

    // ───────────────────────── State / IPC ─────────────────────────
    property bool barVisible: true
    // Bar settings live in the Settings app (SettingsPages/BarPage.qml).
    function openSettings() { if (Refs.settings) Refs.settings.openPage("BarPage"); }
    property bool barLive: true

    function rebuildBar() { barLive = false; rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 80; onTriggered: root.barLive = true }
    Connections {
        target: cfg
        function onPositionChanged() { root.rebuildBar(); }
        function onStyleChanged() { root.rebuildBar(); }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
        function setPosition(pos: string): void { if (root.positions.indexOf(pos) >= 0) cfg.position = pos; }
        function cyclePosition(): void {
            cfg.position = root.positions[(root.positions.indexOf(cfg.position) + 1) % 4];
        }
        function setStyle(st: string): void { if (root.styles.indexOf(st) >= 0) cfg.style = st; }
        function setStatsMode(mode: string): void { if (root.statsModes.indexOf(mode) >= 0) cfg.statsMode = mode; }
        function customize(): void { root.openSettings(); }
        function moveModule(id: string, section: string): void {
            if (root.valid(id) && root.sections.indexOf(section) >= 0) root.moveTo(id, section);
        }
        function shiftModule(id: string, delta: int): void { if (root.valid(id)) root.shiftBy(id, delta); }
    }

    // ───────────────────────── System stats ─────────────────────────
    property int cpuUsage: 0
    property int memPercent: 0
    property real memUsedG: 0
    property real memTotalG: 0
    property int cpuTemp: 0          // package temperature in °C (0 = unknown)
    property string netState: "disconnected"
    property real _prevTotal: 0
    property real _prevIdle: 0

    readonly property string netGlyph: netState === "wifi" ? "\uDB81\uDDA9"
                                     : netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
    readonly property string netTip: netState === "wifi" ? "Wi-Fi connected"
                                   : netState === "ethernet" ? "Ethernet connected" : "Disconnected"

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            const dT = total - root._prevTotal, dI = idle - root._prevIdle;
            if (root._prevTotal > 0 && dT > 0) root.cpuUsage = Math.round(100 * (dT - dI) / dT);
            root._prevTotal = total;
            root._prevIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number(t.match(new RegExp(k + ":\\s+(\\d+)"))[1]);
            const total = kb("MemTotal"), used = total - kb("MemAvailable");
            root.memPercent = Math.round(100 * used / total);
            root.memUsedG = used / 1048576;
            root.memTotalG = total / 1048576;
        }
    }

    // CPU package temperature. The hwmon number changes between boots, so look up the
    // "coretemp" sensor once and read its first input (millidegrees) from then on.
    Process {
        id: tempFinder
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = coretemp ] && echo $h/temp1_input && break; done"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") tempFile.path = text.trim()
        }
    }
    FileView {
        id: tempFile
        printErrors: false
        onLoaded: root.cpuTemp = Math.round(Number(text()) / 1000)
    }

    // Notification count: the notifications panel persists its history here
    property int notifCount: 0
    readonly property string notifTip: notifCount > 0 ? "Notifications: " + notifCount : "No notifications"

    FileView {
        id: notifFile
        path: Quickshell.env("HOME") + "/.cache/43pr/notifications.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.notifCount = JSON.parse(text()).length; }
            catch (e) { root.notifCount = 0; }
        }
        onLoadFailed: root.notifCount = 0
    }

    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let st = "disconnected";
                for (const l of text.split("\n")) {
                    if (l === "ethernet:connected") { st = "ethernet"; break; }
                    if (l === "wifi:connected") st = "wifi";
                }
                if (st !== root.netState) root.netState = st;
            }
        }
    }

    Timer {
        interval: 2000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: { statFile.reload(); memFile.reload(); if (tempFile.path !== "") tempFile.reload(); }
    }
    Timer {
        interval: 10000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Process { id: runner }
    function run(cmd) { runner.command = ["sh", "-c", cmd]; runner.running = true; }

    function mediaAct(kind) {
        const p = Marquee.player;
        if (!p) return;
        Marquee.lastActive = p;   // keep controlling this player, even if another one starts playing
        if (kind === "toggle") p.togglePlaying();
        else if (kind === "next") p.next();
        else p.previous();
    }

    readonly property string wsHints: "Left click: Switch to workspace\nRight click: Bar settings\nScroll: Previous / next workspace"

    // ───────────────────────── Interaction model ─────────────────────────
    // Convention used by every bar module:
    //   Left click   → primary action
    //   Right click  → secondary action (falls back to "Bar settings" if the module has none)
    //   Middle click → tertiary action (optional)
    //   Scroll       → adjust a value (optional)
    // Hints declared on a module are shown automatically in its tooltip.
    // States: hover · pressed · active (accent) · warning (danger) · disabled.

    component Lane: GridLayout {
        property int gap: 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: gap
        columnSpacing: gap
    }

    // Hover tooltip, anchored next to `target` on the side facing away from the bar edge.
    component Tip: Item {
        id: tp
        property Item target: parent
        property bool hot: false
        property string title: ""
        property string hints: ""
        property bool shown: false
        property bool suppressed: false   // set on click; cleared when the pointer leaves
        readonly property bool usable: cfg.tooltips && !suppressed && (title !== "" || hints !== "")

        width: 0
        height: 0
        onHotChanged: if (!hot) { shown = false; suppressed = false; }

        Timer {
            interval: 450
            running: tp.hot && tp.usable && !tp.shown
            onTriggered: tp.shown = true
        }

        LazyLoader {
            active: tp.shown && tp.usable

            PopupWindow {
                readonly property var win: tp.target.QsWindow.window
                readonly property point p: win.contentItem.mapFromItem(tp.target, 0, 0)

                anchor.window: win
                anchor.adjustment: PopupAdjustment.Slide
                anchor.rect.x: root.vertical
                    ? (cfg.position === "left" ? p.x + tp.target.width + 6 : p.x - implicitWidth - 6)
                    : p.x + (tp.target.width - implicitWidth) / 2
                anchor.rect.y: root.vertical
                    ? p.y + (tp.target.height - implicitHeight) / 2
                    : (cfg.position === "top" ? p.y + tp.target.height + 6 : p.y - implicitHeight - 6)
                implicitWidth: tcol.implicitWidth + 20
                implicitHeight: tcol.implicitHeight + 14
                color: "transparent"
                visible: true

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: root.bgColor
                    border.width: 1
                    border.color: root.borderColor

                    Column {
                        id: tcol
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            visible: tp.title !== ""
                            text: tp.title
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            visible: tp.hints !== ""
                            text: tp.hints
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    // Behaviour + visual states shared by every interactive bar element.
    component Interactive: Item {
        id: it
        property string tip: ""
        property string primaryHint: ""
        property string secondaryHint: ""      // empty → right click opens bar settings
        property string tertiaryHint: ""
        property string scrollHint: ""
        property string disabledReason: ""
        property bool active: false            // accent tint (e.g. calendar open)
        property bool warning: false           // danger tint (e.g. low battery, muted)
        property bool disabled: false          // dimmed, ignores input, tooltip explains why
        property bool interactive: true        // false → informational only (no hover tint / pointer)
        property bool noTip: false             // never show a tooltip for this element
        signal primary()
        signal secondary()
        signal tertiary()
        signal scrolled(real delta)

        readonly property bool hovered: ma.containsMouse && !disabled
        readonly property string hintText: {
            if (disabled) return disabledReason;
            if (!cfg.tooltipHints) return "";
            const l = [];
            if (primaryHint !== "") l.push("Left click: " + primaryHint);
            l.push("Right click: " + (secondaryHint !== "" ? secondaryHint : "Bar settings"));
            if (tertiaryHint !== "") l.push("Middle click: " + tertiaryHint);
            if (scrollHint !== "") l.push("Scroll: " + scrollHint);
            return l.join("\n");
        }

        function secondaryAction() {
            if (secondaryHint !== "") secondary();
            else root.openSettings();
        }

        opacity: disabled ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // state layer: pressed > active > warning, with a hover overlay
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius
            color: ma.pressed && it.interactive && !it.disabled ? Qt.alpha(Theme.accent, 0.35)
                 : it.active ? Qt.alpha(Theme.accent, 0.22)
                 : it.warning ? Qt.alpha(Theme.danger, 0.16)
                 : Qt.alpha(Theme.text, 0)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: it.hovered && it.interactive ? Qt.alpha(Theme.text, 0.1) : Qt.alpha(Theme.text, 0)
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: it.interactive && !it.disabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: { tipper.suppressed = true; tipper.shown = false; }
            onClicked: mouse => {
                if (it.disabled) return;
                if (mouse.button === Qt.LeftButton) it.primary();
                else if (mouse.button === Qt.MiddleButton) it.tertiary();
                else it.secondaryAction();
            }
            onWheel: wheel => {
                wheel.accepted = it.scrollHint !== "" && !it.disabled;
                if (wheel.accepted) it.scrolled(wheel.angleDelta.y);
            }
        }

        Tip {
            id: tipper
            target: it
            hot: !it.noTip && ma.containsMouse
            title: it.tip
            hints: it.hintText
        }
    }

    // Icon / text module built on Interactive
    component Mod: Interactive {
        id: mod
        property string mid: ""          // set by Slot; used by generic icon modules
        property string text: ""
        property string vtext: text
        property string glyph: ""
        property string vglyph: glyph
        property real glyphSize: 16
        property real baseSize: 11
        property color color: Theme.text
        property bool bold: false
        property real yOffset: 0
        property int spacing: root.sizeIconGap
        property int padX: 20

        readonly property color fg: warning ? Theme.danger : active ? Theme.accent : color
        readonly property string shown: root.vertical ? vtext : text
        readonly property string shownGlyph: root.vertical ? vglyph : glyph

        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.vertical ? root.panelThick : content.implicitWidth + padX
        implicitHeight: root.vertical ? Math.max(20, content.implicitHeight + 8)
                                      : Math.max(root.panelThick - 2, content.implicitHeight)

        GridLayout {
            id: content
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.vertical ? 0 : mod.yOffset
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 2
            columnSpacing: mod.spacing

            Text {
                visible: mod.shownGlyph !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shownGlyph
                color: mod.fg
                font.family: Theme.iconFont
                font.pixelSize: mod.glyphSize
                renderType: Text.NativeRendering
            }
            Text {
                visible: mod.shown !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shown
                color: mod.fg
                font.family: Theme.iconFont
                font.bold: mod.bold
                font.pixelSize: mod.baseSize
                renderType: Text.NativeRendering
            }
        }
    }

    component Slot: Loader {
        required property string modelData
        property Component clockComp: null
        visible: root.modVisible(modelData)
        Layout.alignment: Qt.AlignCenter
        sourceComponent: modelData === "clock" ? clockComp : (root.comps[modelData] ?? root.comps.icon)
        onLoaded: if (item.mid !== undefined) item.mid = modelData
    }

    // One of the three bar sections: a rounded panel holding a Lane of Slots
    component Panel: Rectangle {
        id: panel
        property var model: []
        property Component clockComp: null
        readonly property Item lane: laneItem

        visible: (root.vertical ? laneItem.implicitHeight : laneItem.implicitWidth) > 0
        width: root.vertical ? root.panelThick : laneItem.implicitWidth + 4
        height: root.vertical ? laneItem.implicitHeight + 4 : root.panelThick
        radius: root.barRadius
        color: root.joined ? "transparent" : root.bgColor
        border.width: cfg.border && !root.joined ? 1 : 0
        border.color: root.borderColor

        Lane {
            id: laneItem
            anchors.centerIn: parent
            Repeater {
                model: panel.model
                delegate: Slot { clockComp: panel.clockComp }
            }
        }
    }

    component Rule: Rectangle {
        height: 1
        color: Qt.alpha(Theme.text, 0.12)
    }

    // Dimmed automatically when `enabled: false` is set on it or a parent.

    // `step` snaps the value (0 = continuous)

    // One button style for everything clickable in the settings window.
    //   plain    → transparent until selected/hovered (tabs, segments)
    //   primary  → accent-filled (Done)


    // Label on the left; whatever you put inside goes on the right.

    component Arrow: Item {
        id: ar
        property string glyph: ""
        signal clicked()
        width: 28
        height: 26
        Text {
            anchors.centerIn: parent
            text: ar.glyph
            color: arMa.containsMouse ? Theme.accent : Theme.text
            font.family: Theme.iconFont
            font.pixelSize: root.sz.calArrow
        }
        MouseArea {
            id: arMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ar.clicked()
        }
    }

    // Scrolling now-playing text. Rotated 90° by its parent on vertical bars.
    component MarqueeStrip: Item {
        clip: true
        Row {
            x: Marquee.animating ? Marquee.x : 0
            spacing: Marquee.gap
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.vertical ? 0 : root.iconYOffset

            Repeater {
                model: Marquee.animating ? 2 : 1
                delegate: Text {
                    required property int index
                    text: Marquee.text
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: root.sz.marquee
                    renderType: root.vertical ? Text.QtRendering : Text.NativeRendering
                    // first copy is width-limited/elided when not scrolling
                    width: index === 0 ? (Marquee.animating ? Marquee.textW
                                                            : Math.min(Marquee.textW, Marquee.maxW))
                                       : implicitWidth
                    elide: index === 0 && !Marquee.animating ? Text.ElideRight : Text.ElideNone
                }
            }
        }
    }

    // ───────────────────────── Module components ─────────────────────────
    // Generic icon button: net / notif / wall / settings / power (driven by moduleDefs)
    Component {
        id: iconC
        Mod {
            property var def: root.defMap[mid] ?? ({})
            readonly property bool isNet: mid === "net"
            baseSize: mid === "power" ? root.sz.power : root.sz.icon
            yOffset: root.iconYOffset
            text: isNet ? root.netGlyph : (def.g ?? "")
            tip: isNet ? root.netTip : mid === "notif" ? root.notifTip : (def.tip ?? "")
            primaryHint: def.hint ?? ""
            warning: isNet && root.netState === "disconnected"
            onPrimary: if (def.cmd) root.run(def.cmd)
        }
    }

    // CPU / Temp / RAM — "default": `CPU 12%`   "compact": small icon + `12%`
    Component {
        id: statsC
        Lane {
            Repeater {
                model: (cfg.showTemp && root.cpuTemp > 0) ? ["CPU", "TEMP", "RAM"] : ["CPU", "RAM"]
                delegate: Mod {
                    required property string modelData
                    readonly property bool isCpu: modelData === "CPU"
                    readonly property bool isTemp: modelData === "TEMP"
                    readonly property bool compact: cfg.statsMode === "compact"
                    readonly property int val: isCpu ? root.cpuUsage : isTemp ? root.cpuTemp : root.memPercent
                    readonly property string unit: isTemp ? "°" : "%"

                    baseSize: root.sz.stat
                    glyphSize: root.sz.stat + 2
                    glyph: compact ? (isCpu ? "\uDB81\uDE1A" : isTemp ? "\uDB81\uDD0F" : "\uDB80\uDF5B") : ""
                    text: compact ? val + unit : modelData + " " + val + unit
                    spacing: compact ? 4 : root.sizeIconGap
                    padX: compact ? 12 : 20

                    interactive: false
                    warning: val >= 85
                    tip: isCpu ? "CPU usage: " + val + "%"
                         : isTemp ? "CPU temperature: " + val + " °C"
                               : "Memory: " + root.memUsedG.toFixed(1) + " / " + root.memTotalG.toFixed(1)
                                 + " GiB (" + val + "%)"
                }
            }
        }
    }

    Component {
        id: wsC
        Item {
            id: wsRoot
            // The delegate of the focused workspace; the pill slides to it.
            property Item focusItem: null

            // True while the special workspace (scratchpad) is shown on the focused monitor.
            property bool inSpecial: false

            Connections {
                target: Hyprland
                // data is "<special workspace name>,<monitor>"; the name is empty when it closes.
                function onRawEvent(event) {
                    if (event.name === "activespecial")
                        wsRoot.inSpecial = event.data.split(",")[0] !== ""
                }
            }

            Component.onCompleted: {
                var sp = Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name
                inSpecial = sp !== undefined && sp !== ""
            }

            implicitWidth: root.vertical ? root.panelThick : (inSpecial ? specialLabel.width : wsLane.implicitWidth) + 8
            implicitHeight: (inSpecial ? specialLabel.height : wsLane.implicitHeight) + (root.vertical ? 12 : 0)

            // Sliding highlight behind the numbers (drawn first, so it sits under them).
            Rectangle {
                id: wsPill
                visible: wsRoot.focusItem !== null && !wsRoot.inSpecial
                radius: Math.min(width, height) / 2
                color: Theme.accent
                x: wsRoot.focusItem ? wsLane.x + wsRoot.focusItem.x : 0
                y: wsRoot.focusItem ? wsLane.y + wsRoot.focusItem.y : 0
                width: wsRoot.focusItem ? wsRoot.focusItem.width : 0
                height: wsRoot.focusItem ? wsRoot.focusItem.height : 0
                Behavior on x { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            }

            // While the special workspace (scratchpad) is open, the numbers fold into one label pill.
            Rectangle {
                id: specialLabel
                visible: wsRoot.inSpecial
                anchors.centerIn: parent
                width: specialText.implicitWidth + 20
                height: 20
                radius: height / 2
                color: Theme.accent

                Text {
                    id: specialText
                    anchors.centerIn: parent
                    text: root.vertical ? "\u2726" : "\u2726 scratchpad"
                    color: Theme.bgPanel
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run("$HOME/.config/hypr/scripts/scratchpad.sh toggle")
                }
            }

            Lane {
                id: wsLane
                visible: !wsRoot.inSpecial
                anchors.centerIn: parent
                gap: 2

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Item {
                        id: dot
                        required property var modelData
                        visible: modelData.id > 0
                        Layout.alignment: Qt.AlignCenter
                        readonly property bool occupied: modelData.toplevels !== undefined && modelData.toplevels.values.length > 0
                        readonly property bool isFocused: modelData.focused
                        implicitWidth: root.vertical ? root.panelThick - 8 : Math.max(22, wsText.implicitWidth + 12)
                        implicitHeight: 20

                        onIsFocusedChanged: if (isFocused) wsRoot.focusItem = dot
                        Component.onCompleted: if (isFocused) wsRoot.focusItem = dot

                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: String(dot.modelData.id)
                            color: dot.modelData.urgent ? Theme.danger
                                 : dot.isFocused ? Theme.bgPanel
                                 : dotMa.containsMouse ? Theme.accent2
                                 : dot.occupied ? Theme.text
                                 : Qt.alpha(Theme.textFaint, 0.7)
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: dot.isFocused
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        MouseArea {
                            id: dotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: { dotTip.suppressed = true; dotTip.shown = false; }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) root.openSettings();
                                else dot.modelData.activate();
                            }
                        }

                        Tip {
                            id: dotTip
                            hot: dotMa.containsMouse
                            title: "Workspace " + dot.modelData.id
                                   + (dot.modelData.urgent ? " · urgent" : dot.modelData.focused ? " · focused" : "")
                            hints: cfg.tooltipHints ? root.wsHints : ""
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => root.run("hyprctl dispatch 'hl.dsp.focus({workspace=\"e"
                                       + (e.angleDelta.y > 0 ? "+1" : "-1") + "\"})'")
            }
        }
    }

    Component {
        id: mediaC
        Interactive {
            readonly property bool playing: Marquee.player !== null && Marquee.player.isPlaying === true
            readonly property real len: Math.min(Marquee.textW, Marquee.maxW)   // visible text length

            implicitWidth: root.vertical ? root.panelThick : len + 20
            implicitHeight: root.vertical ? len + 20 : 18

            tip: Marquee.text
            primaryHint: playing ? "Pause" : "Play"
            secondaryHint: "Next track"
            tertiaryHint: "Previous track"
            onPrimary: root.mediaAct("toggle")
            onSecondary: root.mediaAct("next")
            onTertiary: root.mediaAct("prev")

            // On vertical bars the same marquee is rotated: reads bottom→top on the left, top→bottom on the right.
            MarqueeStrip {
                anchors.centerIn: parent
                width: parent.len
                height: 18
                rotation: root.vertical ? (cfg.position === "left" ? -90 : 90) : 0
            }
        }
    }

    Component {
        id: volumeC
        Mod {
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool ready: !!(sink && sink.audio)
            readonly property real vol: ready ? sink.audio.volume : 0
            readonly property bool muted: ready ? sink.audio.muted : false

            glyphSize: root.sz.icon
            glyph: muted || vol <= 0 ? "\uDB81\uDF5F" : "\uDB81\uDD7E"
            warning: muted
            disabled: !ready
            disabledReason: "No audio output available"
            tip: !ready ? "Volume" : muted ? "Volume: muted" : "Volume: " + Math.round(vol * 100) + "%"
            primaryHint: "Open sound settings"
            secondaryHint: "Mute / unmute"
            scrollHint: "Adjust volume"

            onPrimary: root.run("qs ipc call settings sound")
            onSecondary: root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
            onScrolled: delta => {
                if (!ready) return;
                sink.audio.volume = Math.max(0, Math.min(1.0, sink.audio.volume + (delta / 120) * 0.02));
            }
        }
    }

    Component {
        id: batteryC
        Mod {
            baseSize: root.sz.batText
            glyphSize: root.sz.batIcon
            glyph: (root.batCharging ? "\uf0e7 " : "") + root.batIcon
            vglyph: root.batIcon
            text: root.batPct + "%"
            vtext: root.batPct + ""
            interactive: false
            warning: root.batLow
            active: root.vertical && root.batCharging
            tip: root.batTip
        }
    }

    // ───────────────────────── The bar ─────────────────────────
    Variants {
        model: root.barLive ? Quickshell.screens : []

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: cfg.position !== "bottom"
                bottom: cfg.position !== "top"
                left: cfg.position !== "right"
                right: cfg.position !== "left"
            }
            implicitWidth: root.vertical ? root.panelThick + root.effEdge : 0
            implicitHeight: root.vertical ? 0 : root.panelThick + root.effEdge
            color: "transparent"
            visible: root.barVisible

            Item {
                id: frame
                anchors {
                    fill: parent
                    topMargin: root.edgeMargin("top")
                    bottomMargin: root.edgeMargin("bottom")
                    leftMargin: root.edgeMargin("left")
                    rightMargin: root.edgeMargin("right")
                }

                Rectangle {
                    visible: root.joined
                    anchors.fill: parent
                    radius: root.barRadius
                    color: root.bgColor
                    border.width: cfg.border ? 1 : 0
                    border.color: root.borderColor
                }

                Panel {
                    model: root.startList
                    anchors.left: frame.left
                    anchors.top: frame.top
                }

                Panel {
                    id: clockPanel
                    model: root.centerList
                    clockComp: clockC
                    anchors.horizontalCenter: root.vertical ? undefined : frame.horizontalCenter
                    anchors.verticalCenter: root.vertical ? frame.verticalCenter : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined

                    property bool calOpen: false
                    property int monthOffset: 0

                    // Tick every second only when the format shows seconds (letters outside 'quoted text').
                    SystemClock {
                        id: clk
                        precision: /s/.test(cfg.clockFormat.replace(/'[^']*'/g, "")) ? SystemClock.Seconds : SystemClock.Minutes
                    }

                    Component {
                        id: clockC
                        Mod {
                            bold: true
                            baseSize: root.sz.clock
                            text: Qt.formatDateTime(clk.date, cfg.clockFormat || "HH:mm")
                            vtext: Qt.formatDateTime(clk.date, "HH") + "\n" + Qt.formatDateTime(clk.date, "mm")
                            active: clockPanel.calOpen
                            tip: Qt.formatDate(clk.date, "dddd, d MMMM yyyy")
                            primaryHint: clockPanel.calOpen ? "Close calendar" : "Open calendar"
                            onPrimary: {
                                clockPanel.monthOffset = 0;
                                clockPanel.calOpen = !clockPanel.calOpen;
                            }
                        }
                    }

                    LazyLoader {
                        active: clockPanel.calOpen

                        PopupWindow {
                            readonly property point p: bar.contentItem.mapFromItem(clockPanel, 0, 0)

                            anchor.window: bar
                            anchor.rect.x: root.vertical
                                ? (cfg.position === "left" ? p.x + clockPanel.width + 6
                                                           : p.x - implicitWidth - 6)
                                : p.x + (clockPanel.width - implicitWidth) / 2
                            anchor.rect.y: root.vertical
                                ? p.y + (clockPanel.height - implicitHeight) / 2
                                : (cfg.position === "top" ? p.y + clockPanel.height + 4
                                                          : p.y - implicitHeight - 4)
                            implicitWidth: calBox.gridW + 2 * calBox.pad
                            implicitHeight: calCol.implicitHeight + 2 * calBox.pad
                            color: "transparent"
                            visible: true

                            Rectangle {
                                id: calBox
                                anchors.fill: parent
                                radius: 4
                                color: root.bgColor
                                border.width: cfg.border ? 1 : 0
                                border.color: root.borderColor

                                readonly property int firstDay: 1
                                readonly property int cellW: 36
                                readonly property int cellH: 30
                                readonly property int pad: 16
                                readonly property int gridW: cellW * 7

                                readonly property date now: clk.date
                                readonly property date view: new Date(now.getFullYear(), now.getMonth() + clockPanel.monthOffset, 1)

                                readonly property var cells: {
                                    const first = (view.getDay() - firstDay + 7) % 7;
                                    const y = view.getFullYear(), m = view.getMonth();
                                    const ty = now.getFullYear(), tm = now.getMonth(), td = now.getDate();
                                    return Array.from({ length: 42 }, (_, i) => {
                                        const d = new Date(y, m, i - first + 1);
                                        return {
                                            n: d.getDate(),
                                            inMonth: d.getMonth() === m,
                                            today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                                        };
                                    });
                                }

                                WheelHandler {
                                    onWheel: e => clockPanel.monthOffset += (e.angleDelta.y > 0 ? -1 : 1)
                                }

                                Column {
                                    id: calCol
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Column {
                                        spacing: 2
                                        Text {
                                            text: Qt.formatTime(calBox.now, "HH:mm")
                                            color: Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sz.calTime
                                            font.bold: true
                                        }
                                        Text {
                                            text: Qt.formatDate(calBox.now, "dddd, d MMMM yyyy")
                                            color: Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sz.calDate
                                        }
                                    }

                                    Rule { width: calBox.gridW }

                                    Item {
                                        width: calBox.gridW
                                        height: 26

                                        Arrow {
                                            anchors.left: parent.left
                                            glyph: "\uDB80\uDD41"
                                            onClicked: clockPanel.monthOffset -= 1
                                        }

                                        Item {
                                            anchors.centerIn: parent
                                            width: monthTitle.implicitWidth + 16
                                            height: parent.height
                                            Text {
                                                id: monthTitle
                                                anchors.centerIn: parent
                                                text: Qt.formatDate(calBox.view, "MMMM yyyy")
                                                color: titleMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sz.calMonth
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: titleMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: clockPanel.monthOffset = 0
                                            }
                                        }

                                        Arrow {
                                            anchors.right: parent.right
                                            glyph: "\uDB80\uDD42"
                                            onClicked: clockPanel.monthOffset += 1
                                        }
                                    }

                                    Row {
                                        Repeater {
                                            model: 7
                                            delegate: Text {
                                                required property int index
                                                width: calBox.cellW
                                                horizontalAlignment: Text.AlignHCenter
                                                text: Qt.locale().dayName((index + calBox.firstDay) % 7, Locale.ShortFormat)
                                                color: Theme.textDim
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sz.calWeekday
                                            }
                                        }
                                    }

                                    Grid {
                                        columns: 7
                                        Repeater {
                                            model: calBox.cells
                                            delegate: Item {
                                                required property var modelData
                                                width: calBox.cellW
                                                height: calBox.cellH

                                                Rectangle {
                                                    visible: parent.modelData.today
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    radius: Theme.radius
                                                    color: Qt.alpha(Theme.accent, 0.45)
                                                    border.width: 1
                                                    border.color: Theme.accent
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: parent.modelData.n
                                                    color: parent.modelData.inMonth ? Theme.text : Theme.textFaint
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: root.sz.calDay
                                                    font.bold: parent.modelData.today
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Panel {
                    model: root.endList
                    anchors.right: root.vertical ? undefined : frame.right
                    anchors.bottom: root.vertical ? frame.bottom : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined
                }
            }
        }
    }
}