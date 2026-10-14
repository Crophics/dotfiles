import QtQuick
import "../"

// Dropdown: a button showing the current choice, opening a list under it.
// `options` are the labels shown; `current` is the selected label (or index, see `currentIndex`).
Item {
    id: sel
    property var options: []
    property int currentIndex: -1
    property string placeholder: "Choose…"
    property bool open: false
    property real listWidth: Math.max(width, 220)
    signal picked(int index)

    implicitWidth: 200
    width: implicitWidth
    height: 28

    // Raise the row we sit in so the list draws over the rows below it.
    onOpenChanged: {
        var p = parent
        while (p) {
            if (p.popupOpen !== undefined) { p.popupOpen = open; break }
            p = p.parent
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: area.containsMouse || sel.open ? Theme.alpha(Theme.accent, 0.08) : Theme.trackBg
        border.width: 1
        border.color: sel.open ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: caret.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: sel.currentIndex >= 0 && sel.currentIndex < sel.options.length ? sel.options[sel.currentIndex] : sel.placeholder
            color: sel.currentIndex >= 0 ? Theme.text : Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Text {
            id: caret
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: sel.open ? "▴" : "▾"
            color: Theme.textDim
            font.pixelSize: 10
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sel.open = !sel.open
        }
    }

    // Click anywhere else to close.
    MouseArea {
        visible: sel.open
        x: -3000; y: -3000; width: 6000; height: 6000
        z: -1
        onClicked: sel.open = false
    }

    Rectangle {
        visible: sel.open
        z: 10
        x: sel.width - width
        y: sel.height + 4
        width: sel.listWidth
        height: Math.min(list.contentHeight + 8, 260)
        radius: Theme.radius
        color: Theme.bgPanel
        border.width: 1
        border.color: Theme.accent

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: sel.options
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property string modelData
                required property int index
                width: list.width
                height: 28
                radius: 6
                color: hov.hovered ? Theme.alpha(Theme.accent, 0.12) : (index === sel.currentIndex ? Theme.alpha(Theme.accent, 0.07) : "transparent")
                HoverHandler { id: hov }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    color: index === sel.currentIndex ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { sel.open = false; sel.picked(index) }
                }
            }
        }
    }
}
