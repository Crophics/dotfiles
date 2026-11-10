import QtQuick
import "../"

// Slider with a value readout. `value` is controlled by the caller (bind it to the
// setting); `moved` reports the new value, snapped to `step`, while dragging.
Item {
    id: s
    property real from: 0
    property real to: 1
    property real step: 0.05
    property real value: 0
    property string unit: ""
    property int decimals: 0
    property string displayText: value.toFixed(decimals) + unit
    signal moved(real value)
    signal committed(real value)    // once, when the drag ends
    property real _last: value

    implicitWidth: 210
    implicitHeight: 26

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    function snapped(r) {
        var v = from + Math.max(0, Math.min(1, r)) * (to - from)
        return Math.max(from, Math.min(to, Math.round(v / step) * step))
    }

    Item {
        id: area
        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 16

        Rectangle {
            id: track
            width: parent.width
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.trackBg
            border.width: 1
            border.color: Theme.border

            Rectangle {
                id: fill
                width: track.width * s.ratio
                height: parent.height
                radius: 2
                color: Theme.accent
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.animFast } }
            }
            Rectangle {
                width: 12
                height: 12
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: fill.width - width / 2
                color: Theme.text
                border.width: 2
                border.color: Theme.accent
                scale: drag.pressed ? 1.3 : 1
                Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function at(mx) { s._last = s.snapped((mx - 6) / track.width); s.moved(s._last) }
            onPressed: mouse => at(mouse.x)
            onPositionChanged: mouse => { if (pressed) at(mouse.x) }
            onReleased: s.committed(s._last)
        }
    }

    Text {
        id: readout
        width: 52
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: s.displayText
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
