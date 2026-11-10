import QtQuick
import "../"

// Pick a font: shows the current one, opens a search list where every name is drawn in its own face.
Column {
    id: fp
    property string label: ""
    property string family: ""
    property real size: 11
    property var families: []
    property bool open: false
    property string query: ""
    signal picked(string family)
    signal sized(real size)

    width: parent ? parent.width : 0
    spacing: 6

    readonly property var matches: {
        var q = query.toLowerCase()
        return families.filter(f => q === "" || f.toLowerCase().indexOf(q) >= 0).slice(0, 8)
    }

    SetRow {
        label: fp.label
        hint: fp.family
        clickable: true
        selected: fp.open
        onClicked: fp.open = !fp.open
        SetSlider {
            from: 8; to: 18; step: 1; unit: " pt"
            value: fp.size
            onCommitted: v => fp.sized(v)
        }
        SetButton { label: fp.open ? "Close" : "Change"; onClicked: fp.open = !fp.open }
    }
    SetDetail {
        visible: fp.open
        SetSub {
            label: "Search"
            SetTextField { implicitWidth: 240; placeholder: "Type a font name"; text: fp.query; onEdited: v => fp.query = v }
        }
        Repeater {
            model: fp.matches
            delegate: Rectangle {
                required property string modelData
                width: parent ? parent.width : 0
                height: 32
                radius: Theme.radius
                color: hov.hovered ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                border.width: 1
                border.color: modelData === fp.family ? Theme.accent : "transparent"
                HoverHandler { id: hov }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: modelData
                    color: Theme.text
                    font.family: modelData
                    font.pixelSize: 14
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { fp.picked(modelData); fp.open = false }
                }
            }
        }
        Text {
            visible: fp.matches.length === 0
            text: "No fonts match"
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
}
