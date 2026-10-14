import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// A settings page drawn from the option registry (hypr/options.json). Set `group` to the
// registry page name. Changes go through scripts/options.py, which saves and applies them.
SetPage {
    id: page
    property string group: ""

    readonly property string home: Quickshell.env("HOME")
    property var registry: []
    property var saved: ({})
    readonly property var mine: registry.filter(o => o.page === group)
    readonly property var items: {
        var out = [], last = ""
        for (var i = 0; i < mine.length; i++) {
            if (mine[i].section !== last) { last = mine[i].section; out.push({ heading: last }) }
            out.push(mine[i])
        }
        return out
    }

    function byId(id) { return registry.find(o => o.id === id) }
    function realId(o) { return o.mirror || o.id }
    function valueOf(o) {
        var id = realId(o)
        if (saved[id] !== undefined) return saved[id]
        var base = byId(id)
        return base ? base.default : undefined
    }
    function isDirty(o) {
        var base = byId(realId(o))
        return base && saved[base.id] !== undefined
    }
    property var queued: null          // newest command that arrived while the script was running
    function run(args) {
        var cmd = [home + "/.config/hypr/scripts/options.py"].concat(args)
        if (runner.running) { queued = cmd; return }
        runner.command = cmd
        runner.running = true
    }
    function set(o, v) {
        var id = realId(o)
        var s = Object.assign({}, saved)
        var base = byId(id)
        if (base && v === base.default) delete s[id]; else s[id] = v
        saved = s                      // update the UI at once; the script saves and applies
        run(["set", id, JSON.stringify(v)])
        if (base && base.hook === "opacity") Theme.bgAlpha = v
    }
    function resetAll() {
        var ids = mine.filter(o => o.path || o.pref).map(o => o.id)
        var s = Object.assign({}, saved)
        ids.forEach(i => delete s[i])
        saved = s
        run(["reset"].concat(ids))
        if (mine.some(o => o.hook === "opacity")) Theme.bgAlpha = byId("windows.opacity").default
    }
    function isEnabled(o) { return !o.enabledIf || valueOf(byId(o.enabledIf)) === true }

    Process {
        id: runner
        onExited: if (page.queued) { var c = page.queued; page.queued = null; runner.command = c; runner.running = true }
    }
    FileView {
        id: regFile
        path: page.home + "/.config/hypr/options.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { page.registry = JSON.parse(text()).options } catch (e) { console.warn("options.json:", e) } }
    }
    FileView {
        id: stateFile
        path: page.home + "/.config/quickshell/state/options.json"
        printErrors: false
        onLoaded: { try { page.saved = JSON.parse(text()) } catch (e) { page.saved = {} } }
        onLoadFailed: error => page.saved = {}
    }

    Repeater {
        model: page.items
        delegate: Loader {
            required property var modelData
            width: parent ? parent.width : 0
            sourceComponent: modelData.heading !== undefined ? headingC : rowC
            Component {
                id: headingC
                SetSection { text: modelData.heading }
            }
            Component {
                id: rowC
                OptionRow {
                    opt: modelData
                    value: page.valueOf(modelData)
                    dirty: page.isDirty(modelData)
                    enabled: page.isEnabled(modelData)
                    onMoved: v => {
                        if (modelData.path) page.set(modelData, v)
                        else if (modelData.hook === "opacity") Theme.bgAlpha = v      // shell follows live; saved on release
                    }
                    onChanged: v => page.set(modelData, v)
                    onReset: {
                        var id = page.realId(modelData)
                        page.run(["reset", id])
                        var s = Object.assign({}, page.saved); delete s[id]; page.saved = s
                        if (page.byId(id).hook === "opacity") Theme.bgAlpha = page.byId(id).default
                    }
                }
            }
        }
    }

    Item { width: 1; height: 6 }
    SetButton { label: "Reset " + page.group.toLowerCase(); onClicked: page.resetAll() }
}
