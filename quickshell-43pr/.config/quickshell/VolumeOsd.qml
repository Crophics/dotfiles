import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Scope {
    // Exposed so shell.qml can make this popup and the brightness popup replace each other.
    property alias showing: root.showing
    function dismiss() { root.dismiss() }
    property var osd: root

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "mediaosd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: root.showing ? hitbox : null }

    readonly property int topGap: 30
    readonly property int keepVisible: 40
    readonly property int toolsHeight: 22

    readonly property var numSpec: ({
        osdScale:      { min: 70,   max: 160,   def: 100,  step: 10,  unit: "%" },
        flyoutWidth:   { min: 200,  max: 500,   def: 320,  step: 20,  unit: "px" },
        volTimeout:    { min: 600,  max: 5000,  def: 1200, step: 200, unit: "s" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({})
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var posKeys: ["volOffsetX", "volOffsetY"]

    property real volOffsetX: 0
    property real volOffsetY: 0

    property int osdScale: numSpec.osdScale.def
    property int flyoutWidth: numSpec.flyoutWidth.def
    property int volTimeout: numSpec.volTimeout.def

    readonly property real scaleFactor: osdScale / 100
    readonly property real curX: volOffsetX
    readonly property real curY: volOffsetY

    readonly property bool volumeMoved: volOffsetX !== 0 || volOffsetY !== 0

    readonly property bool movedFromDefault: volumeMoved
        || osdScale !== numSpec.osdScale.def
        || flyoutWidth !== numSpec.flyoutWidth.def
        || volTimeout !== numSpec.volTimeout.def

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/mediaosd-state.json"

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.triggerOsd() }
        function onMutedChanged() { root.triggerOsd() }
    }

    property bool ready: false
    property bool showing: false
    property bool dragging: false
    readonly property bool hovered: flyoutHover.hovered || toolsHover.hovered

    readonly property Item activeCard: flyout

    Timer {
        interval: 2000
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: hideTimer
        interval: root.volTimeout
        onTriggered: {
            if (root.hovered || root.dragging)
                hideTimer.restart()
            else
                root.showing = false
        }
    }

    function triggerOsd() {
        if (!ready)
            return
        showing = true
        hideTimer.restart()
    }

    // Volume popup settings live in the Settings app (SettingsPages/PopupsPage.qml).
    function openSettings() {
        if (Refs.settings) Refs.settings.openPage("PopupsPage")
    }

    // Hide the plain popup (used when the brightness popup takes its place).
    function dismiss() {
        if (!dragging)
            showing = false
    }

    function closeAll() {
        dragging = false
        showing = false
    }

    onShowingChanged: {
        if (!showing)
            dragging = false
    }

    IpcHandler {
        target: "mediaosd"
        function settings(): void { root.openSettings() }
        function hide(): void { root.closeAll() }
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    function fmtValue(key, v) {
        var s = numSpec[key]
        if (s.unit === "s")
            return (v / 1000).toFixed(1) + "s"
        if (s.full && v >= s.max)
            return "full"
        return v + s.unit
    }

    function setPosition(x, y) {
        var nx = x
        var ny = y
        if (width > 0 && height > 0) {
            var w = hitbox.width
            var minX = keepVisible - width / 2 - w / 2
            var maxX = width / 2 - keepVisible + w / 2
            var minY = -topGap
            var maxY = Math.max(minY, height - keepVisible - topGap)
            nx = Math.max(minX, Math.min(maxX, x))
            ny = Math.max(minY, Math.min(maxY, y))
        }
        volOffsetX = nx
        volOffsetY = ny
    }

    function resetPos() {
        volOffsetX = 0
        volOffsetY = 0
        saveState()
    }

    function resetPosition() {
        resetPos()
    }

    function reposition() {
        if (showing)
            setPosition(curX, curY)
    }

    onOsdScaleChanged: reposition()
    onFlyoutWidthChanged: reposition()

    function setNumber(key, v) {
        var s = numSpec[key]
        root[key] = clamp(v, s.min, s.max)
    }

    function toggleSetting(key) {
        root[key] = !root[key]
        saveState()
    }

    function resetKey(key) {
        root[key] = numSpec[key].def
        saveState()
    }

    function resetAll() {
        posKeys.forEach(function (k) { root[k] = 0 })
        numKeys.forEach(function (k) { root[k] = numSpec[k].def })
        boolKeys.forEach(function (k) { root[k] = boolDefaults[k] })
        saveState()
    }

    function saveState() {
        var s = {}
        posKeys.forEach(function (k) { s[k] = root[k] })
        numKeys.forEach(function (k) { s[k] = root[k] })
        boolKeys.forEach(function (k) { s[k] = root[k] })
        stateFile.setText(JSON.stringify(s))
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())

                root.posKeys.forEach(function (k) {
                    if (typeof s[k] === "number")
                        root[k] = s[k]
                })
                root.numKeys.forEach(function (k) {
                    if (typeof s[k] === "number") {
                        var spec = root.numSpec[k]
                        root[k] = root.clamp(s[k], spec.min, spec.max)
                    }
                })
                root.boolKeys.forEach(function (k) {
                    if (typeof s[k] === "boolean")
                        root[k] = s[k]
                })
            } catch (e) {
                console.warn("mediaosd: could not read saved state:", e)
            }
        }
    }

    Item {
        id: scene
        anchors.fill: parent

        Item {
            id: hitbox
            width: root.activeCard.width * root.scaleFactor
            height: (root.activeCard.height + root.toolsHeight) * root.scaleFactor
            x: (scene.width - width) / 2 + root.curX
            y: root.topGap + root.curY
        }

        OsdCard {
            id: flyout
            host: root
            xOffset: root.volOffsetX
            yOffset: root.volOffsetY
            open: root.showing
            width: root.flyoutWidth
            height: 28
            radius: 36

            HoverHandler {
                id: flyoutHover
                enabled: flyout.open
            }

            Text {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                text: {
                    if (root.muted)
                        return "󰖁"
                    if (root.volume <= 0)
                        return "󰕿"
                    if (root.volume < 0.5)
                        return "󰖀"
                    return "󰕾"
                }

                font.family: "Symbols Nerd Font"
                font.pixelSize: 20
                color: Theme.text
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
                font.pixelSize: 12
                font.bold: true
                color: Theme.text
            }

            Rectangle {
                anchors.left: icon.right
                anchors.leftMargin: 15
                anchors.right: parent.right
                anchors.rightMargin: 68
                anchors.verticalCenter: parent.verticalCenter
                height: 5
                radius: 4
                color: "#555555"

                Rectangle {
                    width: root.muted ? 0 : parent.width * Math.min(root.volume, 1)
                    height: parent.height
                    radius: 4
                    color: Theme.text
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
            }
        }

        Item {
            id: tools
            width: root.activeCard.width
            height: root.toolsHeight
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.curX
            anchors.top: parent.top
            anchors.topMargin: root.topGap + root.curY + root.activeCard.height * root.scaleFactor
            transformOrigin: Item.Top
            scale: root.scaleFactor
            visible: opacity > 0
            opacity: (root.showing && (root.hovered || root.dragging)) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            HoverHandler {
                id: toolsHover
                enabled: root.showing
            }

            Item {
                anchors.centerIn: parent
                width: 60
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 36; height: 4; radius: 2
                    color: Theme.text
                    opacity: (dragArea.containsMouse || root.dragging) ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                DragArea {
                    id: dragArea
                    anchors.fill: parent
                    host: root
                    scene: scene
                }
            }

            FooterButton {
                id: settingsButton
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                color: "transparent"
                label: "󰒓"
                fontSize: 13
                opacity: hovered ? 1 : 0.7
                onClicked: root.openSettings()
            }
        }
    }
}

component OsdCard: Rectangle {
    property bool open: false
    property var host
    property real xOffset: 0
    property real yOffset: 0

    color: Theme.bg
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: xOffset
    anchors.top: parent.top
    anchors.topMargin: host.topGap + yOffset
    transformOrigin: Item.Top
    opacity: open ? 1 : 0
    visible: opacity > 0
    scale: (open ? 1 : 0.9) * host.scaleFactor

    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
}

component FooterButton: Rectangle {
    id: fb
    property string label: ""
    property int fontSize: 11
    property bool active: false
    readonly property bool hovered: fbArea.containsMouse
    signal clicked()

    width: 16; height: 16; radius: 6
    color: Theme.bg
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: fb.label
        font.family: "Symbols Nerd Font"
        font.pixelSize: fb.fontSize
        font.bold: true
        color: fb.active ? Theme.accent : (fb.hovered ? Theme.text : Theme.textDim)
    }

    MouseArea {
        id: fbArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: fb.clicked()
    }
}

component GlyphButton: Text {
    signal clicked()
    font.family: "Symbols Nerd Font"
    color: Theme.text
    MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
}

component DragArea: MouseArea {
    id: da
    property var host
    property Item scene
    property real pressX: 0
    property real pressY: 0
    property real startX: 0
    property real startY: 0

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

    function finish() {
        if (!host.dragging)
            return
        host.dragging = false
        host.saveState()
    }

    onPressed: function (mouse) {
        var p = da.mapToItem(da.scene, mouse.x, mouse.y)
        pressX = p.x
        pressY = p.y
        startX = host.curX
        startY = host.curY
        host.dragging = true
    }
    onPositionChanged: function (mouse) {
        if (!host.dragging)
            return
        var p = da.mapToItem(da.scene, mouse.x, mouse.y)
        host.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
    }
    onReleased: finish()
    onCanceled: finish()
    onDoubleClicked: host.resetPosition()
}

}