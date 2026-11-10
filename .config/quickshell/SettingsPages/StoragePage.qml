import QtQuick
import Quickshell.Io
import "../"

// Drives and cleanup, in the same style as the other settings pages.
SetPage {
    id: page
    title: "STORAGE"

    property var drives: []
    property var filesystems: []
    property var cleanupInfo: ({yay:0, pacman:0, journal:0, trash:0, flatpak:0, cliphist:0, thumbs:0})
    property string confirming: ""     // key of the cleanup row waiting for a second click

    readonly property var cleanupDefaults: ({yay:0, pacman:0, journal:0, trash:0, flatpak:0, cliphist:0, thumbs:0})
    readonly property var sizeUnits: ({
        B:1, K:1024, KB:1024, KIB:1024,
        M:1048576, MB:1048576, MIB:1048576,
        G:1073741824, GB:1073741824, GIB:1073741824,
        T:1099511627776, TB:1099511627776, TIB:1099511627776
    })

    function formatBytes(b) {
        if (!isFinite(b) || b < 0) return "0 B"
        var u = ["B", "KB", "MB", "GB", "TB"]
        var i = 0
        var v = b
        while (v >= 1024 && i < u.length - 1) { v /= 1024; ++i }
        return (i ? v.toFixed(1) : Math.round(v)) + " " + u[i]
    }

    function formatCount(n) {
        var v = Math.round(n) || 0
        return v + (v === 1 ? " ITEM" : " ITEMS")
    }

    function parseSize(v) {
        if (!v) return 0
        var m = v.trim().match(/^([0-9.]+)\s*([A-Za-z]*)$/)
        if (!m) return 0
        var n = parseFloat(m[1])
        if (isNaN(n)) return 0
        return n * (m[2] ? (sizeUnits[m[2].toUpperCase()] || 1) : 1)
    }

    function usageColor(p) { return p >= 90 ? Theme.danger : p >= 75 ? Theme.accent2 : Theme.accent }
    function usageWidth(p) { return Math.min(1, Math.max(0, p / 100)) }
    function ignoredMount(m) { return ["/proc", "/sys", "/run", "/dev"].some(function(x) { return m.indexOf(x) === 0 }) }
    function ignoredFilesystem(f) { return ["tmpfs", "devtmpfs", "overlay"].some(function(x) { return f.indexOf(x) === 0 }) }

    function parseDfLine(line) {
        var f = line.trim().split(/\s+/)
        if (f.length < 6) return null
        var d = {
            filesystem: f[0], total: parseInt(f[1]), used: parseInt(f[2]),
            available: parseInt(f[3]), percent: parseInt(f[4]), mount: f.slice(5).join(" ")
        }
        if ([d.total, d.used, d.available, d.percent].some(isNaN) || ignoredMount(d.mount) || ignoredFilesystem(d.filesystem)) return null
        return d
    }

    // btrfs subvolumes (/, /home, /var/log ...) are separate mounts of one partition, and df reports the
    // whole partition for each. Show each partition once, under its shortest mount point.
    function mergeMounts(list) {
        var byDev = {}, out = []
        for (var i = 0; i < list.length; ++i) {
            var it = list[i], seen = byDev[it.filesystem]
            if (!seen) { it.others = 0; byDev[it.filesystem] = it; out.push(it); continue }
            seen.others++
            if (it.mount.length < seen.mount.length) seen.mount = it.mount
        }
        return out
    }

    function parseDriveData(data) {
        var disks = []
        try {
            var obj = JSON.parse(data)
            if (!obj.blockdevices) return disks
            for (var i = 0; i < obj.blockdevices.length; ++i) {
                var d = obj.blockdevices[i]
                if (d.type === "disk" && !/^(zram|loop|ram|sr)/.test(d.name))
                    disks.push({ name: d.name || "", model: d.model || "", size: parseInt(d.size) || 0, type: d.type || "", tran: d.tran || "" })
            }
        } catch (e) { console.log("lsblk JSON error:", e) }
        return disks
    }

    // The partitions of a disk (as listed by df), biggest first.
    function partitionsOf(diskName) {
        return filesystems
            .filter(function (f) { return f.filesystem.indexOf("/dev/" + diskName) === 0 })
            .sort(function (a, b) { return b.used - a.used })
    }
    function segmentColor(i) { return [Theme.accent, Theme.accent2, Theme.textDim, Theme.border][Math.min(i, 3)] }

    // The cleanup actions, biggest first. `amount` is a size in bytes (clipboard: item count).
    readonly property var cleanupDefs: [
        { key: "trash", label: "TRASH", action: "EMPTY", title: "EMPTY TRASH?",
          message: "This permanently deletes everything in ~/.local/share/Trash.",
          command: "rm -rf -- \"$HOME/.local/share/Trash/files/\"* \"$HOME/.local/share/Trash/info/\"*" },
        { key: "cliphist", label: "CLIPBOARD HISTORY", action: "WIPE", title: "WIPE CLIPBOARD HISTORY?",
          message: "This permanently clears your entire clipboard history (cliphist).",
          command: "cliphist wipe" },
        { key: "yay", label: "YAY CACHE", action: "CLEAN", title: "CLEAR YAY CACHE?",
          message: "CACHE_PLACEHOLDER",
          command: "rm -rf -- \"$HOME/.cache/yay/\"*" },
        { key: "pacman", label: "PACMAN CACHE", action: "CLEAN", title: "CLEAN PACMAN CACHE?",
          message: "Keeps only the newest cached version of each package and removes packages that are no longer installed. Snapper snapshots still cover rollbacks.",
          command: "pkexec sh -c 'paccache -rk1; paccache -ruk0'" },
        { key: "journal", label: "JOURNAL", action: "7 DAYS", title: "VACUUM JOURNAL?",
          message: "Keep only the last 7 days of system logs.",
          command: "pkexec journalctl --vacuum-time=7d" },
        { key: "flatpak", label: "FLATPAK UNUSED", action: "CLEAN", title: "REMOVE UNUSED FLATPAKS?",
          message: "This removes unused Flatpak runtimes and packages.",
          command: "flatpak uninstall --unused -y" }
    ]
    readonly property var cleanupItems: cleanupDefs
        .map(function (d) { return Object.assign({ amount: cleanupInfo[d.key] || 0 }, d) })
        .sort(function (a, b) {
            // The clipboard is a count, not bytes: keep it out of the size ranking.
            var x = a.key === "cliphist" ? (a.amount > 0 ? 1 : 0) : a.amount
            var y = b.key === "cliphist" ? (b.amount > 0 ? 1 : 0) : b.amount
            return y - x
        })
    readonly property real reclaimable: cleanupItems.reduce(function (sum, i) { return i.key === "cliphist" ? sum : sum + i.amount }, 0)

    function runCommand(c) { commandProcess.command = ["sh", "-c", c]; commandProcess.running = true }
    function refreshAll() { pDrives.running = pStorage.running = pCleanup.running = true }

    Process {
        id: pDrives
        command: ["sh", "-c", "lsblk -J -b -d -o NAME,MODEL,SIZE,TYPE,TRAN 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: page.drives = page.parseDriveData(text) }
        stderr: StdioCollector {}
    }

    Process {
        id: pStorage
        command: ["sh", "-c", "df -P -B1 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var fs = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var item = page.parseDfLine(lines[i])
                    if (item) fs.push(item)
                }
                page.filesystems = page.mergeMounts(fs)
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: pCleanup
        command: [
            "sh", "-c",
            "p() { printf '%s %s\\n' \"$1\" \"${2:-0}\"; }; " +
            "p YAY \"$(du -sb \"$HOME/.cache/yay\" 2>/dev/null | awk '{print $1}')\"; " +
            "p PACMAN \"$(du -sb /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')\"; " +
            "p JOURNAL \"$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+ ?[BKMGT]' | tail -1 | tr -d ' ')\"; " +
            "p TRASH \"$(du -sb \"$HOME/.local/share/Trash\" 2>/dev/null | awk '{print $1}')\"; " +
            "p FLATPAK \"$(flatpak uninstall --unused --assumeno 2>/dev/null | grep -oE '[0-9.]+ ?(kB|MB|GB|TB)' | tail -1 | tr -d ' ')\"; " +
            "p CLIPHIST \"$(cliphist list 2>/dev/null | wc -l)\"; " +
            "p THUMBS \"$(du -sb \"$HOME/.cache/quickshell/thumbs\" 2>/dev/null | awk '{print $1}')\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var info = {yay: 0, pacman: 0, journal: 0, trash: 0, flatpak: 0, cliphist: 0, thumbs: 0}
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].trim().split(/\s+/)
                    var k = p[0] ? p[0].toLowerCase() : ""
                    if (p.length > 1 && info[k] !== undefined) info[k] = page.parseSize(p.slice(1).join(" "))
                }
                page.cleanupInfo = info
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: commandProcess
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onRunningChanged: { if (!running) page.refreshAll() }
    }

    Timer { interval: 10000; running: true; repeat: true; onTriggered: page.refreshAll() }
    Timer { id: confirmTimer; interval: 4000; onTriggered: page.confirming = "" }
    Component.onCompleted: page.refreshAll()

    // ── drives ──
    Repeater {
        model: page.drives
        delegate: Column {
            id: drive
            required property var modelData
            width: parent ? parent.width : 0
            spacing: 10
            readonly property var parts: page.partitionsOf(modelData.name)
            readonly property real used: parts.reduce(function (s, p) { return s + p.used }, 0)

            SetSection { text: modelData.name + "  ·  " + (modelData.model || "").trim() + (modelData.tran ? "  ·  " + modelData.tran : "") }

            Rectangle {
                width: parent.width
                height: card.implicitHeight + 28
                radius: Theme.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.border

                Column {
                    id: card
                    x: 14; y: 14
                    width: parent.width - 28
                    spacing: 10

                    Row {
                        width: parent.width
                        Text { text: page.formatBytes(drive.used) + " used of " + page.formatBytes(modelData.size); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; width: parent.width / 2 }
                        Text { text: page.formatBytes(Math.max(0, modelData.size - drive.used)) + " free"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12; width: parent.width / 2; horizontalAlignment: Text.AlignRight }
                    }
                    Rectangle {
                        width: parent.width; height: 12; radius: 6
                        color: Theme.trackBg
                        clip: true
                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: drive.parts
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: modelData.used / Math.max(1, drive.modelData.size) * parent.width
                                    height: parent.height
                                    color: page.segmentColor(index)
                                }
                            }
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 18
                        Repeater {
                            model: drive.parts
                            delegate: Row {
                                required property var modelData
                                required property int index
                                spacing: 6
                                Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: page.segmentColor(index) }
                                Text { text: modelData.mount + "  " + page.formatBytes(modelData.used) + " of " + page.formatBytes(modelData.total); color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 10 }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── cleanup ──
    SetSection { text: "Cleanup" }
    Text {
        width: parent.width
        text: page.reclaimable > 0 ? page.formatBytes(page.reclaimable) + " can be freed" : "Nothing to clean right now"
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    Repeater {
        model: page.cleanupItems
        delegate: SetRow {
            required property var modelData
            readonly property bool waiting: page.confirming === modelData.key
            label: modelData.label
            hint: waiting ? modelData.message.replace("CACHE_PLACEHOLDER", "Deletes everything in ~/.cache/yay.")
                          : (modelData.key === "cliphist" ? page.formatCount(modelData.amount) : page.formatBytes(modelData.amount))
            wrapHint: true
            enabled: modelData.amount > 0
            SetButton {
                label: waiting ? "Confirm" : modelData.action.toLowerCase()
                primary: waiting
                onClicked: {
                    if (!waiting) { page.confirming = modelData.key; confirmTimer.restart(); return }
                    page.confirming = ""
                    page.runCommand(modelData.command)
                }
            }
        }
    }
}
