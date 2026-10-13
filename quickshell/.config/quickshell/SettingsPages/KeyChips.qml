import QtQuick
import "../"

// A key combination drawn as keycaps: SUPER + SHIFT + L. Same height as a SetButton, so the
// two line up inside a SetRow.
Item {
    id: chips
    property var mods: []
    property string key: ""
    property bool dim: false

    implicitWidth: caps.width
    width: implicitWidth
    height: 26
    opacity: dim ? 0.45 : 1

Row {
    id: caps
    spacing: 4
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
        model: chips.mods.concat(chips.key !== "" ? [chips.key] : [])
        delegate: Rectangle {
            required property string modelData
            required property int index
            readonly property bool isKey: index === chips.mods.length
            width: cap.implicitWidth + 14
            height: 22
            radius: 5
            color: isKey ? Theme.alpha(Theme.accent, 0.14) : Theme.trackBg
            border.width: 1
            border.color: isKey ? Theme.accent : Theme.border

            Text {
                id: cap
                anchors.centerIn: parent
                text: modelData
                color: isKey ? Theme.accent : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1
            }
        }
    }

    Text {
        visible: chips.key === "" && chips.mods.length === 0
        text: "NOT SET"
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1.5
    }
}
}
