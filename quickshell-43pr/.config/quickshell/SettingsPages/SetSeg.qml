import QtQuick
import "../"

// Segmented picker: one button per option, the current one highlighted.
Row {
    id: seg
    property var options: []
    property string current: ""
    signal picked(string value)

    spacing: 4

    Repeater {
        model: seg.options
        delegate: Rectangle {
            required property string modelData
            readonly property bool on: modelData === seg.current
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
                onClicked: seg.picked(modelData)
            }
        }
    }
}
