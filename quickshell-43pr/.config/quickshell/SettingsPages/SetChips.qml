import QtQuick
import "../"

// Like SetSeg, but wraps onto more lines. Use it where there can be many options.
Flow {
    id: chips
    property var options: []
    property string current: ""
    signal picked(string value)
    spacing: 4

    // A single row hugs the right edge (like SetSeg); several rows read left to right.
    readonly property real estimate: {
        var w = 0
        for (var i = 0; i < options.length; i++) w += options[i].length * 8 + 22 + spacing
        return w
    }
    readonly property bool oneRow: estimate <= width
    layoutDirection: oneRow ? Qt.RightToLeft : Qt.LeftToRight

    Repeater {
        model: chips.oneRow ? chips.options.slice().reverse() : chips.options
        delegate: Rectangle {
            required property string modelData
            readonly property bool on: modelData === chips.current
            width: label.implicitWidth + 22
            height: 26
            radius: Theme.radius
            color: on ? Theme.alpha(Theme.accent, 0.15)
                      : (area.containsMouse ? Theme.alpha(Theme.accent, 0.06) : "transparent")
            border.width: 1
            border.color: on ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Text {
                id: label
                anchors.centerIn: parent
                text: modelData.toUpperCase()
                color: parent.on ? Theme.accent : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1.5
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chips.picked(modelData)
            }
        }
    }
}
