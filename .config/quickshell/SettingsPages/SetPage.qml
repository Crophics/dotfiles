import QtQuick
import QtQuick.Controls
import "../"

// Shared frame for the settings pages: a title, a rule, then a scrolling column.
// Children declared inside a SetPage go straight into that column.
Item {
    id: page
    property string title: ""
    default property alias content: column.data

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: 45
        contentWidth: width
        contentHeight: column.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 6
            background: Rectangle { color: "transparent" }
            contentItem: Rectangle { color: "transparent" }
        }

        Column {
            id: column
            width: flick.width
            spacing: 10

            Text {
                text: page.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 19
                font.letterSpacing: 3
                bottomPadding: 4
            }
            Rectangle { width: parent.width; height: 1; color: Theme.border }
        }
    }
}
