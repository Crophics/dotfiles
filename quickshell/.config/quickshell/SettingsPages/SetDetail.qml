import QtQuick
import "../"

// Panel that opens under a row to show its details and extra options.
Rectangle {
    id: d
    default property alias content: col.data
    width: parent ? parent.width : 0
    height: col.implicitHeight + 24
    radius: Theme.radius
    color: Theme.alpha(Theme.bgCard, 0.7)
    border.width: 1
    border.color: Theme.border

    Column {
        id: col
        x: 14
        y: 12
        width: d.width - 28
        spacing: 10
    }
}
