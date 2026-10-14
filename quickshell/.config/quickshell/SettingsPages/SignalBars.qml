import QtQuick
import "../"

Row {
    property int percent: 0
    readonly property int level: percent >= 75 ? 4 : percent >= 50 ? 3 : percent >= 25 ? 2 : percent > 0 ? 1 : 0
    spacing: 2
    height: 14
    Repeater {
        model: 4
        Rectangle {
            required property int index
            width: 3
            height: 4 + index * 3
            anchors.bottom: parent.bottom
            radius: 1
            color: index < parent.level ? Theme.accent : Theme.border
        }
    }
}
