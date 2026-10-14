import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Cursor, icon theme and fonts. Everything goes through scripts/appearance.py.
SetPage {
    id: page
    title: "APPEARANCE"

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/appearance.py"
    property var info: ({ cursor: "", cursorSize: 24, icons: "", font: "", fontSize: 11, mono: "", monoSize: 11 })
    property var cursors: []
    property var iconThemes: []
    property var fonts: []
    property var monos: []

    function load() { pGet.running = true }
    function apply(args) { run.run([[script].concat(args)]) }
    Component.onCompleted: { pGet.running = true; pCur.running = true; pIco.running = true; pFonts.running = true; pMono.running = true }
    NmRun { id: run; onFinished: ok => page.load() }

    Process { id: pGet; command: [page.script, "get"]; stdout: StdioCollector { onStreamFinished: { try { page.info = JSON.parse(text) } catch (e) {} } } }
    Process { id: pCur; command: [page.script, "list", "cursors"]; stdout: StdioCollector { onStreamFinished: { try { page.cursors = JSON.parse(text) } catch (e) {} } } }
    Process { id: pIco; command: [page.script, "list", "icons"]; stdout: StdioCollector { onStreamFinished: { try { page.iconThemes = JSON.parse(text) } catch (e) {} } } }
    Process { id: pFonts; command: [page.script, "list", "fonts"]; stdout: StdioCollector { onStreamFinished: { try { page.fonts = JSON.parse(text) } catch (e) {} } } }
    Process { id: pMono; command: [page.script, "list", "mono"]; stdout: StdioCollector { onStreamFinished: { try { page.monos = JSON.parse(text) } catch (e) {} } } }

    SetSection { text: "Cursor" }
    SetRow {
        label: "Cursor theme"
        hint: "Apps use it as they open. Already open windows keep their old cursor"
        SetSelect {
            implicitWidth: 220
            options: page.cursors
            currentIndex: page.cursors.indexOf(page.info.cursor)
            onPicked: i => page.apply(["cursor", page.cursors[i], String(page.info.cursorSize)])
        }
    }
    SetRow {
        label: "Cursor size"
        hint: "Already open windows keep their old size"
        SetSeg {
            options: ["16", "20", "24", "28", "32", "40", "48"]
            current: String(page.info.cursorSize)
            onPicked: v => page.apply(["cursor", page.info.cursor, v])
        }
    }

    SetSection { text: "Icons" }
    SetRow {
        label: "Icon theme"
        hint: "Apps pick it up as they open"
        SetSelect {
            implicitWidth: 220
            options: page.iconThemes
            currentIndex: page.iconThemes.indexOf(page.info.icons)
            onPicked: i => page.apply(["icons", page.iconThemes[i]])
        }
    }

    SetSection { text: "Fonts" }
    FontPicker {
        label: "Interface font"
        family: page.info.font
        size: page.info.fontSize
        families: page.fonts
        onPicked: f => page.apply(["font", f, String(page.info.fontSize)])
        onSized: s => page.apply(["font", page.info.font, String(s)])
    }
    FontPicker {
        label: "Monospace font"
        family: page.info.mono
        size: page.info.monoSize
        families: page.monos
        onPicked: f => page.apply(["mono", f, String(page.info.monoSize)])
        onSized: s => page.apply(["mono", page.info.mono, String(s)])
    }
}
