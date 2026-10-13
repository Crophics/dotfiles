import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../"

Item {
    id: page
    property var drives: []
    property var filesystems: []
    property var cleanupInfo: ({yay:0, pacman:0, journal:0, trash:0, flatpak:0, cliphist:0, thumbs:0})
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0
    property string pendingAction: ""
    property string pendingTitle: ""
    property string pendingMessage: ""

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
        { key: "thumbs", label: "WALLPAPER PICKER", action: "CLEAR", title: "CLEAR THUMBNAIL CACHE?",
          message: "This permanently deletes everything in ~/.cache/quickshell/thumbs.",
          command: "rm -rf -- \"$HOME/.cache/quickshell/thumbs/\"*" },
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
    function confirmAction(t, m, c) { pendingTitle = t; pendingMessage = m; pendingAction = c; confirmPopup.visible = true }

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

    Rectangle {
        id: confirmPopup
        visible: false; anchors.centerIn: parent; z: 100
        width: Math.min(parent.width - 30, 420); height: 190; radius: Theme.radius
        color: Theme.bg; border.width: 1; border.color: Theme.accent

        Column {
            anchors.fill: parent; anchors.margins: 18; spacing: 12
            Text {
                text: page.pendingTitle; color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 17; font.bold: true
            }
            Text {
                width: parent.width; text: page.pendingMessage; color: Theme.textDim
                font.family: Theme.fontFamily; font.pixelSize: 13; wrapMode: Text.WordWrap
            }
            Item { width: 1; height: 1 }
            Row {
                width: parent.width; spacing: 10
                ToolButton {
                    width: (parent.width - 8) / 2; label: "CANCEL"
                    onClicked: confirmPopup.visible = false
                }
                ToolButton {
                    width: (parent.width - 8) / 2; label: "CONFIRM"; accent: true
                    onClicked: { confirmPopup.visible = false; page.runCommand(page.pendingAction) }
                }
            }
        }
    }

    Timer { interval: 10000; running: true; repeat: true; onTriggered: page.refreshAll() }
    Component.onCompleted: page.refreshAll()

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        spacing: 14

        Text {
            text: "STORAGE"; color: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Item {
            width: parent.width; height: parent.height - y

            Flickable {
                id: flick
                anchors.fill: parent; clip: true
                contentWidth: width; contentHeight: list.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    id: scrollBar
                    background: Rectangle {
                        color: Theme.alpha(Theme.border, 0)
                        radius: width / 2
                    }
                    contentItem: Rectangle {
                        color: Theme.accent
                        radius: width / 2
                    }
                }

                Column {
                    id: list
                    width: parent.width; spacing: 10

                    // ── Drives: one bar per drive, split by partition ──
                    Repeater {
                        model: page.drives
                        delegate: Column {
                            id: drive
                            required property var modelData
                            readonly property var parts: page.partitionsOf(modelData.name)
                            readonly property real usedSum: parts.reduce(function (a, p) { return a + p.used }, 0)
                            readonly property real size: Math.max(1, modelData.size)
                            width: list.width
                            spacing: 10

                            Item {
                                width: parent.width; height: 20
                                Text {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - sizeLabel.width - 12
                                    text: (modelData.model || modelData.name || "DRIVE").trim()
                                          + (modelData.tran ? "   " + modelData.tran.toUpperCase() : "")
                                    color: Theme.text; elide: Text.ElideRight
                                    font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true; font.letterSpacing: 1
                                }
                                Text {
                                    id: sizeLabel
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    text: page.formatBytes(modelData.size)
                                    color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 12
                                }
                            }

                            Rectangle {
                                id: stack
                                width: parent.width; height: 30; radius: 7
                                color: Theme.trackBg; border.width: 1; border.color: Theme.border
                                clip: true

                                Row {
                                    anchors.fill: parent; anchors.margins: 1
                                    Repeater {
                                        model: drive.parts
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: Math.max(2, (stack.width - 2) * modelData.used / drive.size)
                                            height: parent.height
                                            color: page.segmentColor(index)
                                            Text {
                                                visible: parent.width > 90
                                                anchors.left: parent.left; anchors.leftMargin: 9
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.mount + "  " + page.formatBytes(modelData.used)
                                                color: Theme.bg; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true
                                            }
                                        }
                                    }
                                    Item {
                                        width: Math.max(0, (stack.width - 2) * (drive.size - drive.usedSum) / drive.size)
                                        height: parent.height
                                        Text {
                                            visible: parent.width > 110
                                            anchors.left: parent.left; anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "free  " + page.formatBytes(drive.size - drive.usedSum)
                                            color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10
                                        }
                                    }
                                }
                            }

                            Flow {
                                width: parent.width; spacing: 18
                                Repeater {
                                    model: drive.parts
                                    delegate: Row {
                                        required property var modelData
                                        required property int index
                                        spacing: 7
                                        Rectangle { width: 9; height: 9; radius: 2; color: page.segmentColor(index); anchors.verticalCenter: parent.verticalCenter }
                                        Text {
                                            text: modelData.mount + (modelData.others > 0 ? " +" + modelData.others : "")
                                                  + "   " + page.formatBytes(modelData.used) + " / " + page.formatBytes(modelData.total)
                                            color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                                        }
                                    }
                                }
                                Row {
                                    spacing: 7
                                    Rectangle { width: 9; height: 9; radius: 2; color: Theme.trackBg; border.width: 1; border.color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "free"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
                                }
                            }
                        }
                    }

                    // ── Cleanup ──
                    Item {
                        width: list.width; height: 40
                        Text {
                            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                            text: "CLEANUP"; color: Theme.accent
                            font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2.5
                        }
                        Text {
                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                            text: page.reclaimable > 0 ? page.formatBytes(page.reclaimable) + " can be reclaimed" : "Nothing to clean"
                            color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }

                    Repeater {
                        model: page.cleanupItems
                        delegate: CleanRow {
                            required property var modelData
                            width: list.width
                            label: modelData.label
                            value: modelData.key === "cliphist" ? page.formatCount(page.cleanupInfo.cliphist) : page.formatBytes(page.cleanupInfo[modelData.key])
                            actionText: modelData.action
                            empty: !modelData.amount
                            onClicked: page.confirmAction(
                                modelData.title,
                                modelData.message === "CACHE_PLACEHOLDER"
                                    ? page.formatBytes(page.cleanupInfo.yay) + " currently in ~/.cache/yay"
                                    : modelData.message,
                                modelData.command
                            )
                        }
                    }
                }
            }
        }
    }

    component ToolButton: Rectangle {
        property string label: ""
        property bool accent: false
        signal clicked()
        height: 38; radius: Theme.radius; color: "#00000000"
        border.width: 1; border.color: Theme.border

        Text {
            anchors.centerIn: parent; text: parent.label
            color: parent.accent ? Theme.accent : Theme.textDim
            font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: .5
        }

        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onEntered: { parent.color = Theme.alpha(Theme.accent, 0.08); parent.border.color = Theme.accent }
            onExited: { parent.color = "#00000000"; parent.border.color = Theme.border }
            onClicked: parent.clicked()
        }
    }

    // One cleanup item: name, size, and its action. Items with nothing to clean are dimmed and inert.
    component CleanRow: Rectangle {
        id: row
        required property string label
        required property string value
        required property string actionText
        property bool empty: false
        signal clicked()

        height: 42
        color: area.containsMouse && !empty ? Theme.alpha(Theme.accent, 0.06) : "transparent"
        opacity: empty ? 0.45 : 1

        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.border }

        Text {
            anchors.left: parent.left; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter
            text: row.label; color: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: 12; font.letterSpacing: 1.5
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Text {
                text: row.value; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontFamily; font.pixelSize: 12
            }
            Rectangle {
                width: actionLabel.implicitWidth + 22; height: 26; radius: Theme.radius
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"; border.width: 1
                border.color: row.empty ? Theme.border : (area.containsMouse ? Theme.accent : Theme.accent2)
                Text {
                    id: actionLabel
                    anchors.centerIn: parent; text: row.actionText
                    color: row.empty ? Theme.textDim : Theme.accent
                    font.family: Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.5
                }
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent; hoverEnabled: true
            enabled: !row.empty
            cursorShape: row.empty ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
