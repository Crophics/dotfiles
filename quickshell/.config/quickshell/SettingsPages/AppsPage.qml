import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Default apps (which app opens what) and the apps that start at login.
SetPage {
    id: page
    title: "APPS"

    readonly property string home: Quickshell.env("HOME")
    readonly property string appsScript: home + "/.config/hypr/scripts/apps.py"
    readonly property string startupScript: home + "/.config/hypr/scripts/startup.py"

    readonly property var categories: [
        { key: "browser", label: "Web browser", mime: "x-scheme-handler/http" },
        { key: "files", label: "File manager", mime: "inode/directory" },
        { key: "text", label: "Text editor", mime: "text/plain" },
        { key: "image", label: "Images", mime: "image/png" },
        { key: "video", label: "Video", mime: "video/mp4" },
        { key: "audio", label: "Music", mime: "audio/mpeg" },
        { key: "pdf", label: "PDF documents", mime: "application/pdf" },
        { key: "archive", label: "Archives", mime: "application/zip" },
        { key: "email", label: "Email links", mime: "x-scheme-handler/mailto" }
    ]
    property var apps: []
    property var defaults: ({})
    property var startup: []
    property bool pickOpen: false
    property string pickQuery: ""

    function candidates(cat) { return apps.filter(a => a.mimes.indexOf(cat.mime) >= 0) }
    function appName(id) { var a = apps.find(x => x.id === id); return a ? a.name : "" }
    function setDefault(cat, id) {
        var d = Object.assign({}, defaults); d[cat.key] = id; defaults = d
        run.run([[appsScript, "set", cat.key, id]])
    }

    // Exec lines carry field codes like %U that only make sense when opening a file.
    function cleanExec(e) { return e.replace(/\s%[a-zA-Z]/g, "").replace(/%[a-zA-Z]/g, "").trim() }
    function saveStartup(list) {
        startup = list
        startupFile.setText(JSON.stringify(list, null, 1))
    }

    NmRun { id: run }
    Component.onCompleted: { pApps.running = true; pDef.running = true }
    Process { id: pApps; command: [page.appsScript, "list"]; stdout: StdioCollector { onStreamFinished: { try { page.apps = JSON.parse(text) } catch (e) {} } } }
    Process { id: pDef; command: [page.appsScript, "defaults"]; stdout: StdioCollector { onStreamFinished: { try { page.defaults = JSON.parse(text) } catch (e) {} } } }
    FileView {
        id: startupFile
        path: page.home + "/.config/quickshell/state/startup.json"
        printErrors: false
        onLoaded: { try { page.startup = JSON.parse(text()) } catch (e) { page.startup = [] } }
        onLoadFailed: error => page.startup = []
        onSaved: run.run([[page.startupScript]])
    }

    SetSection { text: "Default apps" }
    Repeater {
        model: page.categories
        delegate: SetRow {
            required property var modelData
            readonly property var list: page.candidates(modelData)
            label: modelData.label
            hint: list.length === 0 ? "No installed app handles this" : ""
            controlWidth: 460
            SetChips {
                width: 460
                options: list.map(a => a.name)
                current: page.appName(page.defaults[modelData.key])
                onPicked: v => page.setDefault(modelData, list.find(a => a.name === v).id)
            }
        }
    }

    SetSection { text: "Start at login" }
    Repeater {
        model: page.startup
        delegate: SetRow {
            required property var modelData
            required property int index
            label: modelData.name
            hint: modelData.command
            SetButton { label: "Run now"; onClicked: { Quickshell.execDetached(["sh", "-c", modelData.command]) } }
            SetButton { label: "Remove"; onClicked: page.saveStartup(page.startup.filter((x, i) => i !== index)) }
            SetToggle {
                checked: modelData.enabled !== false
                onToggled: v => page.saveStartup(page.startup.map((x, i) => i === index ? Object.assign({}, x, { enabled: v }) : x))
            }
        }
    }
    Text {
        visible: page.startup.length === 0
        text: "Nothing added. Apps you add here start when you log in."
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    SetRow {
        label: "Add an app"
        hint: "Pick an installed app, or type a command"
        clickable: true
        selected: page.pickOpen
        onClicked: page.pickOpen = !page.pickOpen
        SetButton { label: page.pickOpen ? "Close" : "Add"; primary: true; onClicked: page.pickOpen = !page.pickOpen }
    }
    SetDetail {
        visible: page.pickOpen
        SetSub {
            label: "Installed apps"
            SetTextField { implicitWidth: 240; placeholder: "Search apps"; text: page.pickQuery; onEdited: v => page.pickQuery = v }
        }
        Repeater {
            model: page.pickQuery === "" ? [] : page.apps.filter(a => a.name.toLowerCase().indexOf(page.pickQuery.toLowerCase()) >= 0).slice(0, 6)
            delegate: Rectangle {
                required property var modelData
                width: parent ? parent.width : 0
                height: 30
                radius: Theme.radius
                color: hov.hovered ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                HoverHandler { id: hov }
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12; text: modelData.name; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { page.saveStartup(page.startup.concat([{ name: modelData.name, command: page.cleanExec(modelData.exec), enabled: true }])); page.pickQuery = ""; page.pickOpen = false }
                }
            }
        }
        SetSub {
            label: "Or a command"
            SetTextField { id: cName; implicitWidth: 110; placeholder: "Name" }
            SetTextField { id: cCmd; implicitWidth: 200; placeholder: "command --with args" }
            SetButton {
                label: "Add"; primary: true; enabled: cName.text !== "" && cCmd.text !== ""
                onClicked: { page.saveStartup(page.startup.concat([{ name: cName.text, command: cCmd.text, enabled: true }])); cName.text = ""; cCmd.text = ""; page.pickOpen = false }
            }
        }
    }
    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Startup apps launch the next time you log in. Use Run now to start one straight away."
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
}
