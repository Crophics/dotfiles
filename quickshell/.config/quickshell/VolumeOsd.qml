import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Scope {

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
    property bool settingsOpen: false
    property string settingsTab: "volume"
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
            if (root.hovered || root.settingsOpen || root.dragging)
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

    function openSettings() {
        settingsTab = "volume"
        settingsOpen = true
        showing = true
        hideTimer.restart()
        Qt.callLater(reposition)
    }

    function closeSettings() {
        settingsOpen = false
        dragging = false
        hideTimer.restart()
    }

    function toggleSettings() {
        if (settingsOpen)
            closeSettings()
        else
            openSettings()
    }

    function setSettingsTab(tab) {
        settingsTab = tab
        hideTimer.restart()
        Qt.callLater(reposition)
    }

    function closeAll() {
        settingsOpen = false
        dragging = false
        showing = false
    }

    onShowingChanged: {
        if (!showing) {
            settingsOpen = false
            dragging = false
        }
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
                active: root.settingsOpen
                opacity: (hovered || root.settingsOpen) ? 1 : 0.7
                onClicked: root.toggleSettings()
            }
        }
    }
}

PanelWindow {
    id: settingsWin

    visible: root.settingsOpen
    color: "transparent"
    implicitWidth: 420
    implicitHeight: layout.height
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mediaosd-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property real maxContent: Math.max(240, (screen?.height ?? 800) * 0.85 - 186)

    Connections {
        target: root
        function onSettingsTabChanged() { flick.contentY = 0 }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Theme.bg
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.12)
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeSettings()

        Column {
            id: layout
            width: parent.width

            Item {
                width: parent.width
                height: 60

                Text {
                    x: 20; y: 12
                    text: "OSD settings"
                    font.pixelSize: 15
                    font.bold: true
                    color: Theme.text
                }
                Text {
                    x: 20; y: 34
                    text: "Changes apply live and are saved automatically"
                    font.pixelSize: 10
                    color: Theme.textDim
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    y: 10
                    width: 24; height: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "×"
                    font.pixelSize: 22
                    color: closeArea.containsMouse ? Theme.text : Theme.textDim
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.closeSettings()
                    }
                }
            }

            Item {
                width: parent.width
                height: 40

                Rectangle {
                    x: 20
                    width: parent.width - 40
                    height: 32
                    radius: 16
                    color: Theme.alpha(Theme.text, 0.08)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 4

                        TabButton {
                            width: parent.width / 2
                            label: "Volume"
                            selected: root.settingsTab === "volume"
                            onClicked: root.setSettingsTab("volume")
                        }
                        TabButton {
                            width: parent.width / 2
                            label: "General"
                            selected: root.settingsTab === "general"
                            onClicked: root.setSettingsTab("general")
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                Text {
                    x: 20
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    font.pixelSize: 10
                    color: Theme.textDim
                    text: root.settingsTab === "volume"
                        ? "The volume popup stays open while you adjust these."
                        : "Size and position of the popup."
                }
            }

            Flickable {
                id: flick
                width: parent.width
                height: Math.min(contentCol.height + 12, settingsWin.maxContent)
                contentWidth: width
                contentHeight: contentCol.height + 12
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentCol
                    x: 20
                    width: flick.width - 40

                    Column {
                        visible: root.settingsTab === "volume"
                        width: parent.width

                        SectionHeader { text: "Appearance" }
                        SliderRow {
                            host: root
                            key: "flyoutWidth"
                            label: "Width"
                            hint: "Width of the volume popup"
                            value: root.flyoutWidth
                        }

                        SectionHeader { text: "Behavior" }
                        SliderRow {
                            host: root
                            key: "volTimeout"
                            label: "Hide after"
                            hint: "How long the popup stays after a volume change"
                            value: root.volTimeout
                        }
                    }

                    Column {
                        visible: root.settingsTab === "general"
                        width: parent.width

                        SectionHeader { text: "Size" }
                        SliderRow {
                            host: root
                            key: "osdScale"
                            label: "Scale"
                            hint: "Resizes the popup"
                            value: root.osdScale
                        }

                        SectionHeader { text: "Position" }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            font.pixelSize: 10
                            color: Theme.textDim
                            text: "Hover the popup and drag the handle underneath to move it. Double-click the handle to reset it."
                        }
                        Item { width: 1; height: 10 }
                        Row {
                            spacing: 8
                            ActionButton {
                                label: "Reset position"
                                enabled: root.volumeMoved
                                onClicked: root.resetPos()
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 58

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.alpha(Theme.text, 0.08)
                }

                ActionButton {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Reset all"
                    enabled: root.movedFromDefault
                    onClicked: root.resetAll()
                }
                ActionButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Done"
                    primary: true
                    onClicked: root.closeSettings()
                }
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

component TabButton: Rectangle {
    id: tb
    property string label: ""
    property bool selected: false
    signal clicked()

    height: 24
    radius: 12
    color: selected ? Theme.accent : (tbArea.containsMouse ? Theme.alpha(Theme.text, 0.08) : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text: tb.label
        font.pixelSize: 11
        font.bold: true
        color: tb.selected ? Theme.bg : Theme.textDim
    }

    MouseArea {
        id: tbArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tb.clicked()
    }
}

component ActionButton: Rectangle {
    id: ab
    property string label: ""
    property bool primary: false
    signal clicked()

    implicitWidth: abText.implicitWidth + 28
    width: implicitWidth
    height: 30
    radius: 15
    opacity: enabled ? 1 : 0.4
    color: primary
        ? Theme.accent
        : Theme.alpha(Theme.text, abArea.containsMouse ? 0.18 : 0.1)
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: abText
        anchors.centerIn: parent
        text: ab.label
        font.pixelSize: 11
        font.bold: true
        color: ab.primary ? Theme.bg : Theme.text
    }

    MouseArea {
        id: abArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: ab.clicked()
    }
}

component SectionHeader: Item {
    property string text: ""
    width: parent?.width ?? 0
    height: 32

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: parent.text
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.textDim
    }
}

component ToggleRow: Item {
    id: tr
    property var host
    property string key: ""
    property string label: ""
    property bool checked: false

    width: parent?.width ?? 0
    height: 34
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -8
        radius: 8
        color: trArea.containsMouse && tr.enabled ? Theme.alpha(Theme.text, 0.06) : "transparent"
    }

    Text {
        anchors.left: parent.left
        anchors.right: sw.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: tr.label
        elide: Text.ElideRight
        font.pixelSize: 12
        font.bold: true
        color: Theme.text
    }

    Rectangle {
        id: sw
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36; height: 20; radius: 10
        color: tr.checked ? Theme.accent : "transparent"
        border.width: 1
        border.color: tr.checked ? Theme.accent : Theme.alpha(Theme.text, 0.3)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            width: 14; height: 14; radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: tr.checked ? parent.width - width - 3 : 3
            color: tr.checked ? Theme.bg : Theme.text
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: trArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tr.host.toggleSetting(tr.key)
    }
}

component SliderRow: Item {
    id: sl
    property var host
    property string key: ""
    property string label: ""
    property string hint: ""
    property real value: 0

    readonly property var spec: host.numSpec[key]
    readonly property real range: spec.max - spec.min
    readonly property real frac: (value - spec.min) / range
    readonly property real defFrac: (spec.def - spec.min) / range
    readonly property bool changed: value !== spec.def

    width: parent?.width ?? 0
    height: hint !== "" ? 62 : 48
    opacity: enabled ? 1 : 0.4

    Text {
        x: 0; y: 4
        text: sl.label
        font.pixelSize: 12
        font.bold: true
        color: Theme.text
    }

    Text {
        visible: sl.hint !== ""
        x: 0; y: 21
        width: parent.width - 80
        text: sl.hint
        elide: Text.ElideRight
        font.pixelSize: 10
        color: Theme.textDim
    }

    Row {
        anchors.right: parent.right
        y: 3
        spacing: 6

        Text {
            text: sl.host.fmtValue(sl.key, sl.value)
            font.pixelSize: 11
            font.bold: true
            color: Theme.text
        }
        Text {
            width: 14
            text: "↺"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13
            color: resetArea.containsMouse ? Theme.accent : Theme.textDim
            opacity: sl.changed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: sl.changed
                onClicked: sl.host.resetKey(sl.key)
            }
        }
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        height: 20

        readonly property real knobSize: 14
        readonly property real span: Math.max(1, width - knobSize)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.alpha(Theme.text, 0.18)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: track.knobSize / 2 + sl.defFrac * track.span - 1
            width: 2; height: 8; radius: 1
            color: Theme.alpha(Theme.text, 0.35)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: sl.frac * track.span + track.knobSize / 2
            height: 4
            radius: 2
            color: Theme.accent
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: sl.frac * track.span
            width: track.knobSize; height: track.knobSize; radius: track.knobSize / 2
            color: Theme.text
            scale: slArea.pressed ? 1.2 : (slArea.containsMouse ? 1.1 : 1)
            Behavior on scale { NumberAnimation { duration: 100 } }
        }

        MouseArea {
            id: slArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true

            function setFromX(mx) {
                var f = Math.max(0, Math.min(1, (mx - track.knobSize / 2) / track.span))
                var steps = Math.round(f * sl.range / sl.spec.step)
                var v = Math.min(sl.spec.max, sl.spec.min + steps * sl.spec.step)
                if (v !== sl.value)
                    sl.host.setNumber(sl.key, v)
            }

            onPressed: function (mouse) { setFromX(mouse.x) }
            onPositionChanged: function (mouse) { if (pressed) setFromX(mouse.x) }
            onReleased: sl.host.saveState()
            onCanceled: sl.host.saveState()
        }
    }
}

}