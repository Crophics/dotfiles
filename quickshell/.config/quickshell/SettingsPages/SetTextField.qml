import QtQuick
import "../"

// Single-line text input in the settings style. `edited` fires as the user types.
Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    signal edited(string value)

    implicitWidth: 240
    width: implicitWidth
    height: 28
    radius: Theme.radius
    color: Theme.trackBg
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.alpha(Theme.accent, 0.4)
        selectedTextColor: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 12
        onTextEdited: f.edited(text)
    }

    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === "" && !input.activeFocus
        text: f.placeholder
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
