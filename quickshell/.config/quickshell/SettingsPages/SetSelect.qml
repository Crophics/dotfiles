import QtQuick
import Quickshell
import "../"

// Dropdown: a button showing the current choice, opening a list under it.
// The list lives in a overlay over the whole window, so it is never clipped by the rows around it and
// every click on it reaches it (items outside their parent's bounds don't get clicks in Qt Quick).
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

    readonly property Item overlay: QsWindow.window ? QsWindow.window.contentItem : null

    function place() {
        if (!overlay) return
        const p = sel.mapToItem(overlay, sel.width, sel.height)
        popup.x = Math.max(8, p.x - popup.width)
        popup.y = Math.min(p.y + 4, overlay.height - popup.height - 8)
    }
    onOpenChanged: if (open) place()
    // Follow the button if the page scrolls while the list is open.
    Timer { interval: 60; repeat: true; running: sel.open; onTriggered: sel.place() }

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

    // Window-wide overlay: a click outside the list closes it, a click on an item picks it.
    Item {
        id: popupLayer
        parent: sel.overlay
        anchors.fill: parent ? parent : undefined
        visible: sel.open && sel.overlay !== null
        z: 10000

        MouseArea {
            anchors.fill: parent
            onClicked: sel.open = false
            onWheel: wheel => wheel.accepted = true
        }

        Rectangle {
            id: popup
            width: sel.listWidth
            height: Math.min(list.contentHeight + 8, 260)
            radius: Theme.radius
            color: Theme.bgPanel
            border.width: 1
            border.color: Theme.accent

            // swallow clicks on the padding so they don't count as "outside"
            MouseArea { anchors.fill: parent }

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
}
