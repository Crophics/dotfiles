import QtQuick
import "../"

// Small label/value pair for the detail grids.
Column {
    property string label: ""
    property string value: ""
    width: 200
    Text { text: parent.label.toUpperCase(); color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1.5 }
    Text { width: parent.width; text: parent.value === "" ? "—" : parent.value; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
}
