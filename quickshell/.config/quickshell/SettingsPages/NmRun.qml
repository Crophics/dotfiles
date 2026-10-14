import QtQuick
import Quickshell.Io

// Runs commands one after another (each an argv array, no shell involved), stops at the
// first failure and reports its output in `error`.
Item {
    id: r
    property bool busy: false
    property string error: ""
    signal finished(bool ok)
    property var _queue: []
    property int _code: -1
    property bool _got: false

    function run(cmds) { _queue = cmds.slice(); error = ""; busy = true; _next() }
    function _next() {
        if (!_queue.length) { busy = false; finished(error === ""); return }
        var c = _queue.shift()
        _code = -1; _got = false
        console.log("NmRun:", JSON.stringify(c))
        p.command = ["sh", "-c", "\"$@\" 2>&1", "sh"].concat(c)
        p.running = true
    }
    function _check() {
        if (_code < 0 || !_got) return
        console.log("NmRun done:", _code, out.text.trim().slice(0, 200))
        if (_code !== 0) { error = out.text.trim() || ("failed (" + _code + ")"); _queue = [] }
        _next()
    }

    Process {
        id: p
        stdout: StdioCollector { id: out; onStreamFinished: { r._got = true; r._check() } }
        onExited: (code, status) => { r._code = code; r._check() }
    }
}
