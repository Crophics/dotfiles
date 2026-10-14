import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Wi-Fi, Ethernet, hotspot, VPN and general network options, all through NetworkManager (nmcli).
SetPage {
    id: page
    title: "NETWORK"

    // ── state ──
    property string wifiDev: "wlan0"
    property string ethDev: ""
    property string ethState: ""
    property string ethProfile: ""
    property string wifiProfile: ""
    property string wifiState: ""
    property bool wifiOn: false
    property bool btBlocked: false
    property var networks: []
    property var saved: []
    property var vpns: []
    property var info: ({})
    property string expanded: ""        // "cur", "eth", or a joining SSID
    property string joinPw: ""
    property string status: ""
    property bool scanning: false
    property bool importOpen: false
    property bool hiddenOpen: false
    property bool showPw: false
    readonly property bool airplane: !wifiOn && btBlocked
    readonly property var current: networks.find(n => n.inUse) || null
    readonly property bool hotspotOn: wifiProfile === "Hotspot" && wifiState === "connected"

    // Hotspot form
    property string hsName: "apollo-hotspot"
    property string hsPw: ""
    property string hsBand: "2.4 GHz"
    // General
    property string proxyMode: "none"
    property string dnsAll: "Per network"
    property string powerSave: "Default"
    property string hostname: ""

    function splitEsc(line) {
        var out = [], cur = ""
        for (var i = 0; i < line.length; i++) {
            var c = line[i]
            if (c === "\\" && i + 1 < line.length) { cur += line[++i] }
            else if (c === ":") { out.push(cur); cur = "" }
            else cur += c
        }
        out.push(cur)
        return out
    }
    function band(freq) { var f = parseInt(freq); return f >= 5925 ? "6 GHz" : f >= 4900 ? "5 GHz" : "2.4 GHz" }
    function ago(ts) {
        var s = Math.floor(Date.now() / 1000) - parseInt(ts)
        if (!ts || s < 0 || isNaN(s)) return "never used"
        if (s < 3600) return "used " + Math.max(1, Math.floor(s / 60)) + " min ago"
        if (s < 86400) return "used " + Math.floor(s / 3600) + " h ago"
        if (s < 86400 * 14) return "used " + Math.floor(s / 86400) + " days ago"
        return "used " + Math.floor(s / 86400 / 7) + " weeks ago"
    }
    function bytes(n) {
        n = parseFloat(n); if (isNaN(n)) return "—"
        var u = ["B", "KB", "MB", "GB", "TB"], i = 0
        while (n >= 1024 && i < 4) { n /= 1024; i++ }
        return n.toFixed(i > 1 ? 1 : 0) + " " + u[i]
    }
    function savedFor(ssid) { return saved.find(s => s.name === ssid) || null }

    function refresh() {
        pDev.running = true; pRadio.running = true; pList.running = true
        pSaved.running = true; pIp.running = true
    }
    function rescan() { scanning = true; nm.run([["nmcli", "device", "wifi", "rescan"]]); scanTimer.restart() }
    Timer { id: scanTimer; interval: 5000; onTriggered: { page.scanning = false; pList.running = true } }

    Component.onCompleted: { refresh(); rescan(); pGen.running = true }
    Timer { interval: 4000; running: true; repeat: true; onTriggered: page.refresh() }

    NmRun {
        id: nm
        onFinished: ok => { if (!ok) page.status = nm.error; else page.status = ""; page.refresh() }
    }
    NmRun { id: nm2; onFinished: ok => { if (!ok) page.status = nm2.error; page.refresh(); pGen.running = true } }

    // Joining goes through its own runner so a bad or missing password can reopen the password
    // panel here, instead of a separate window popping up (nm-applet used to do that).
    property string joiningSsid: ""
    NmRun {
        id: join
        onFinished: ok => {
            if (ok) { page.status = ""; page.expanded = ""; page.joinPw = ""; page.refresh(); return }
            page.refresh()
            if (/secrets|password|802\.1x|supplicant|auth/i.test(join.error)) {
                page.joinPw = ""
                page.expanded = page.joiningSsid
                page.status = "Couldn't join " + page.joiningSsid + ". Check the password and try again."
            } else {
                page.status = join.error
            }
        }
    }
    function connectTo(ssid, pw, hidden) {
        status = ""
        joiningSsid = ssid
        var s = savedFor(ssid)
        if (s && !hidden) {
            var cmds = []
            if (pw !== "") cmds.push(["nmcli", "connection", "modify", "id", s.name, "wifi-sec.psk", pw])
            cmds.push(["nmcli", "connection", "up", "id", s.name])
            join.run(cmds)
            return
        }
        var cmd = ["nmcli", "device", "wifi", "connect", ssid]
        if (pw !== "") cmd = cmd.concat(["password", pw])
        if (hidden) cmd = cmd.concat(["hidden", "yes"])
        join.run([cmd])
    }

    // ── data ──
    Process {
        id: pDev
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var eth = false
                for (var i = 0; i < lines.length; i++) {
                    var f = page.splitEsc(lines[i])
                    if (f[1] === "wifi" && f[0].indexOf("p2p") < 0) {
                        page.wifiDev = f[0]; page.wifiState = f[2]; page.wifiProfile = f[3]
                    } else if (f[1] === "ethernet" && !eth) {
                        eth = true
                        page.ethDev = f[0]; page.ethState = f[2]; page.ethProfile = f[3]
                    }
                }
            }
        }
    }
    Process {
        id: pRadio
        command: ["sh", "-c", "nmcli radio wifi; rfkill -nr -o TYPE,SOFT | awk '$1==\"bluetooth\"{print $2}' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                page.wifiOn = l[0] === "enabled"
                page.btBlocked = l[1] === "blocked"
            }
        }
    }
    Process {
        id: pList
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,FREQ,SECURITY,RATE,CHAN", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                var best = {}, lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = page.splitEsc(lines[i])
                    if (f.length < 7 || f[1] === "") continue
                    var n = { inUse: f[0] === "*", ssid: f[1], signal: parseInt(f[2]) || 0, freq: f[3], security: f[4],
                              rate: f[5], chan: f[6], band: page.band(f[3]) }
                    var o = best[n.ssid]
                    if (!o || n.inUse || (!o.inUse && n.signal > o.signal)) best[n.ssid] = n
                }
                var arr = Object.keys(best).map(k => best[k])
                arr.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
                page.networks = arr
            }
        }
    }
    Process {
        id: pSaved
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT,TIMESTAMP", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var w = [], v = [], lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = page.splitEsc(lines[i])
                    if (f.length < 5) continue
                    var c = { name: f[0], uuid: f[1], type: f[2], auto: f[3] === "yes", ts: f[4] }
                    if (f[2] === "802-11-wireless" && f[0] !== "Hotspot") w.push(c)
                    else if (f[2] === "vpn" || f[2] === "wireguard") v.push(c)
                }
                w.sort((a, b) => parseInt(b.ts) - parseInt(a.ts))
                page.saved = w
                page.vpns = v
            }
        }
    }
    Process {
        id: pActiveVpn
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"]
        running: true
        stdout: StdioCollector { id: actOut }
    }
    property var activeNames: actOut.text.split("\n").map(l => page.splitEsc(l)[0])

    Process {
        id: pIp
        command: ["sh", "-c",
            "d=" + page.wifiDev + "; nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS device show $d | sed 's/\\\\:/%%/g'; "
            + "echo MAC:$(cat /sys/class/net/$d/address 2>/dev/null); echo RX:$(cat /sys/class/net/$d/statistics/rx_bytes 2>/dev/null); "
            + "echo TX:$(cat /sys/class/net/$d/statistics/tx_bytes 2>/dev/null)"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o = {}, lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var k = lines[i].indexOf(":")
                    if (k < 0) continue
                    var key = lines[i].slice(0, k).replace(/\[\d+\]/, ""), val = lines[i].slice(k + 1).replace(/%%/g, ":")
                    if (key === "IP4.DNS") o[key] = (o[key] ? o[key] + ", " : "") + val
                    else if (!o[key]) o[key] = val
                }
                page.info = o
                pActiveVpn.running = true
            }
        }
    }
    // hotspot settings, proxy, power save, hostname
    Process {
        id: pGen
        command: ["sh", "-c",
            "nmcli -s -g 802-11-wireless.ssid,802-11-wireless.band,802-11-wireless-security.psk connection show id Hotspot 2>/dev/null || printf '\\n\\n\\n'; "
            + "echo @; gsettings get org.gnome.system.proxy mode 2>/dev/null; echo @; hostnamectl hostname; echo @; "
            + "nmcli -g 802-11-wireless.powersave connection show id \"" + page.wifiProfile + "\" 2>/dev/null; echo @; "
            + "nmcli -g ipv4.dns connection show id \"" + page.wifiProfile + "\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("@\n")
                var hs = (parts[0] || "").split("\n")
                if (hs[0]) page.hsName = hs[0]
                page.hsBand = hs[1] === "a" ? "5 GHz" : "2.4 GHz"
                page.hsPw = hs[2] || ""
                page.proxyMode = (parts[1] || "none").trim().replace(/'/g, "")
                page.hostname = (parts[2] || "").trim()
                var ps = (parts[3] || "0").trim()
                page.powerSave = ps === "2" ? "Off" : ps === "3" ? "On" : "Default"
                var d = (parts[4] || "").trim().replace(/[\s;]+/g, ",")
                page.dnsAll = d === "" ? "Per network" : d === "1.1.1.1,1.0.0.1" ? "Cloudflare" : d === "8.8.8.8,8.8.4.4" ? "Google" : d === "9.9.9.9,149.112.112.112" ? "Quad9" : "Per network"
            }
        }
    }
    Process { id: qrProc; onExited: (c, s) => { if (c === 0) { page.qrSource = ""; page.qrSource = "file://" + Quickshell.env("HOME") + "/.cache/qs-wifi-qr.png"; page.qrOpen = true } else page.status = "Couldn't make a QR code" } }
    property bool qrOpen: false
    property string qrSource: ""
    function showQr(profile, ssid) {
        qrProc.command = ["sh", "-c",
            "pw=$(nmcli -s -g 802-11-wireless-security.psk connection show id \"$1\"); mkdir -p ~/.cache; "
            + "qrencode -o ~/.cache/qs-wifi-qr.png -s 8 -m 2 \"WIFI:T:WPA;S:$2;P:$pw;;\"", "sh", profile, ssid]
        qrProc.running = true
    }
    function copyPassword(profile) {
        qrProc.command = ["sh", "-c", "nmcli -s -g 802-11-wireless-security.psk connection show id \"$1\" | wl-copy", "sh", profile]
        qrProc.running = true
    }

    // ── status ──
    Text {
        visible: page.status !== ""
        width: parent.width
        text: page.status
        wrapMode: Text.WordWrap
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    SetRow {
        label: "Airplane mode"
        hint: "Turns off Wi-Fi and Bluetooth together"
        SetToggle {
            checked: page.airplane
            onToggled: v => nm.run(v ? [["nmcli", "radio", "wifi", "off"], ["rfkill", "block", "bluetooth"]]
                                     : [["rfkill", "unblock", "bluetooth"], ["nmcli", "radio", "wifi", "on"]])
        }
    }

    // ── Wi-Fi ──
    SetSection { text: "Wi-Fi" }
    SetRow {
        label: "Wi-Fi"
        hint: !page.wifiOn ? page.wifiDev + " · off"
            : page.current ? page.wifiDev + " · connected to " + page.current.ssid
            : page.wifiDev + " · not connected"
        SetButton { visible: page.wifiOn; label: page.scanning ? "Scanning…" : "Scan"; enabled: !page.scanning; onClicked: page.rescan() }
        SetToggle { checked: page.wifiOn; onToggled: v => nm.run([["nmcli", "radio", "wifi", v ? "on" : "off"]]) }
    }

    SetRow {
        id: curRow
        visible: page.wifiOn && page.current !== null
        clickable: true
        selected: page.expanded === "cur"
        label: page.current ? page.current.ssid : ""
        hint: page.current ? "Connected · " + (page.current.security || "Open") + " · " + page.current.band + " · " + page.current.rate : ""
        leading: [SignalBars { percent: page.current ? page.current.signal : 0 }]
        onClicked: page.expanded = page.expanded === "cur" ? "" : "cur"
        SetButton { label: "Disconnect"; onClicked: nm.run([["nmcli", "device", "disconnect", page.wifiDev]]) }
    }
    SetDetail {
        visible: page.expanded === "cur" && page.wifiOn && page.current !== null
        Flow {
            width: parent.width
            spacing: 18
            KV { label: "Signal"; value: page.current ? page.current.signal + "%" : "" }
            KV { label: "Band / channel"; value: page.current ? page.current.band + " · ch " + page.current.chan : "" }
            KV { label: "Link speed"; value: page.current ? page.current.rate : "" }
            KV { label: "Security"; value: page.current ? (page.current.security || "Open") : "" }
            KV { label: "IPv4"; value: (page.info["IP4.ADDRESS"] || "") }
            KV { label: "Gateway"; value: page.info["IP4.GATEWAY"] || "" }
            KV { label: "DNS"; value: page.info["IP4.DNS"] || "" }
            KV { label: "IPv6"; value: page.info["IP6.ADDRESS"] || "" }
            KV { label: "MAC (in use)"; value: page.info["MAC"] || "" }
            KV { label: "Traffic"; value: "↓ " + page.bytes(page.info["RX"]) + " · ↑ " + page.bytes(page.info["TX"]) }
        }
        NetProfileOptions { profile: page.wifiProfile; wifi: true; active: true }
        Row {
            spacing: 8
            SetButton { label: "Share (QR code)"; onClicked: page.showQr(page.wifiProfile, page.current.ssid) }
            SetButton { label: "Copy password"; onClicked: page.copyPassword(page.wifiProfile) }
            SetButton { label: "Forget network"; onClicked: { nm.run([["nmcli", "connection", "delete", "id", page.wifiProfile]]); page.expanded = "" } }
        }
    }

    // ── Available networks ──
    SetSection { visible: page.wifiOn; text: "Available networks" }
    Repeater {
        model: page.wifiOn ? page.networks.filter(n => !n.inUse) : []
        delegate: Column {
            required property var modelData
            width: parent ? parent.width : 0
            spacing: 6
            readonly property bool secured: modelData.security !== "" && modelData.security !== "--"
            readonly property var sv: page.savedFor(modelData.ssid)

            SetRow {
                clickable: true
                selected: page.expanded === modelData.ssid
                label: modelData.ssid
                hint: (secured ? modelData.security : "Open") + (sv ? " · saved" : "") + " · " + modelData.band
                leading: [SignalBars { percent: modelData.signal }]
                onClicked: {
                    if (!secured || sv) page.connectTo(modelData.ssid, "", false)
                    else { page.joinPw = ""; page.expanded = page.expanded === modelData.ssid ? "" : modelData.ssid }
                }
                SetButton {
                    label: "Connect"; primary: true
                    onClicked: {
                        if (!secured || sv) page.connectTo(modelData.ssid, "", false)
                        else { page.joinPw = ""; page.expanded = page.expanded === modelData.ssid ? "" : modelData.ssid }
                    }
                }
            }
            SetDetail {
                visible: page.expanded === modelData.ssid
                SetSub {
                    label: "Password"
                    SetTextField { id: pwField; implicitWidth: 220; text: page.joinPw; placeholder: "Wi-Fi password"; echoHidden: !page.showPw; onEdited: v => page.joinPw = v }
                    SetButton { label: page.showPw ? "Hide" : "Show"; onClicked: page.showPw = !page.showPw }
                }
                Row {
                    spacing: 8
                    SetButton { label: "Connect"; primary: true; enabled: page.joinPw.length >= 8; onClicked: page.connectTo(modelData.ssid, page.joinPw, false) }
                    SetButton { label: "Cancel"; onClicked: page.expanded = "" }
                }
            }
        }
    }
    SetRow {
        visible: page.wifiOn
        clickable: true
        selected: page.hiddenOpen
        label: "Hidden network…"
        hint: "Join a network that doesn't broadcast its name"
        onClicked: page.hiddenOpen = !page.hiddenOpen
        SetButton { label: "Add"; onClicked: page.hiddenOpen = !page.hiddenOpen }
    }
    SetDetail {
        visible: page.wifiOn && page.hiddenOpen
        SetSub { label: "Network name"; SetTextField { id: hidSsid; implicitWidth: 220; placeholder: "SSID" } }
        SetSub { label: "Password"; hint: "Leave empty for an open network"; SetTextField { id: hidPw; implicitWidth: 220; echoHidden: !page.showPw; placeholder: "Wi-Fi password" } }
        Row {
            spacing: 8
            SetButton { label: "Connect"; primary: true; enabled: hidSsid.text !== ""; onClicked: { page.connectTo(hidSsid.text, hidPw.text, true); page.hiddenOpen = false } }
            SetButton { label: "Cancel"; onClicked: page.hiddenOpen = false }
        }
    }

    // ── Saved ──
    SetSection { text: "Saved networks"; visible: page.saved.length > 0 }
    Repeater {
        model: page.saved
        delegate: SetRow {
            required property var modelData
            label: modelData.name
            hint: page.ago(modelData.ts)
            Text { text: "AUTO"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1.5; anchors.verticalCenter: parent.verticalCenter }
            SetToggle { checked: modelData.auto; onToggled: v => nm.run([["nmcli", "connection", "modify", "id", modelData.name, "connection.autoconnect", v ? "yes" : "no"]]) }
            SetButton { label: "Edit"; onClicked: Quickshell.execDetached(["nm-connection-editor", "--edit", modelData.uuid]) }
            SetButton { label: "Forget"; onClicked: nm.run([["nmcli", "connection", "delete", "id", modelData.name]]) }
        }
    }

    // ── Ethernet ──
    SetSection { text: "Ethernet"; visible: page.ethDev !== "" }
    SetRow {
        visible: page.ethDev !== ""
        clickable: true
        selected: page.expanded === "eth"
        label: page.ethDev
        hint: page.ethState === "connected" ? "Connected · " + page.ethProfile
            : page.ethState === "unavailable" ? "Cable unplugged" : "Disconnected"
        onClicked: page.expanded = page.expanded === "eth" ? "" : "eth"
        SetButton {
            visible: page.ethState !== "unavailable"
            label: page.ethState === "connected" ? "Disconnect" : "Connect"
            onClicked: nm.run([["nmcli", "device", page.ethState === "connected" ? "disconnect" : "connect", page.ethDev]])
        }
    }
    SetDetail {
        visible: page.expanded === "eth" && page.ethDev !== ""
        NetProfileOptions { profile: page.ethProfile; wifi: false; active: page.ethState === "connected" }
    }

    // ── Hotspot ──
    SetSection { text: "Hotspot" }
    SetRow {
        label: "Share this connection"
        hint: "Others join your laptop's Wi-Fi. Uses ethernet as the source while the hotspot is on"
        wrapHint: true
        SetToggle {
            checked: page.hotspotOn
            onToggled: v => {
                if (!v) { nm2.run([["nmcli", "connection", "down", "id", "Hotspot"]]); return }
                if (page.hsPw.length < 8) { page.status = "Set a hotspot password (8+ characters) first"; return }
                nm2.run([["nmcli", "connection", "up", "id", "Hotspot"]])
            }
        }
    }
    SetRow {
        label: "Name"
        SetTextField { id: hsN; implicitWidth: 220; text: page.hsName; placeholder: "Network name" }
    }
    SetRow {
        label: "Password"
        hint: "8 characters or more"
        SetTextField { id: hsP; implicitWidth: 200; text: page.hsPw; echoHidden: !page.showPw; placeholder: "Password" }
        SetButton { label: page.showPw ? "Hide" : "Show"; onClicked: page.showPw = !page.showPw }
        SetButton {
            label: "Apply"; primary: true
            enabled: hsN.text !== "" && hsP.text.length >= 8
            onClicked: {
                page.hsName = hsN.text; page.hsPw = hsP.text
                var band = page.hsBand === "5 GHz" ? "a" : "bg"
                var props = ["802-11-wireless.ssid", hsN.text, "802-11-wireless-security.psk", hsP.text, "802-11-wireless.band", band]
                nm2.run([["sh", "-c", "nmcli -g NAME connection show | grep -qx Hotspot || nmcli connection add type wifi ifname \"$1\" con-name Hotspot autoconnect no ssid \"$2\" 802-11-wireless.mode ap ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$3\"", "sh", page.wifiDev, hsN.text, hsP.text],
                         ["nmcli", "connection", "modify", "id", "Hotspot"].concat(props)].concat(page.hotspotOn ? [["nmcli", "connection", "up", "id", "Hotspot"]] : []))
            }
        }
    }
    SetRow {
        label: "Band"
        hint: "2.4 GHz reaches farther, 5 GHz is faster"
        SetSeg {
            options: ["2.4 GHz", "5 GHz"]
            current: page.hsBand
            onPicked: v => {
                page.hsBand = v
                nm2.run([["nmcli", "connection", "modify", "id", "Hotspot", "802-11-wireless.band", v === "5 GHz" ? "a" : "bg"]])
            }
        }
    }

    // ── VPN ──
    SetSection { text: "VPN" }
    SetRow {
        label: "Add a VPN"
        hint: "Import a WireGuard (.conf) or OpenVPN (.ovpn) file, or build one by hand"
        SetButton { label: "Import file"; onClicked: page.importOpen = !page.importOpen }
        SetButton { label: "Add"; onClicked: Quickshell.execDetached(["nm-connection-editor", "--create"]) }
    }
    SetDetail {
        visible: page.importOpen
        SetSub {
            label: "File path"
            SetTextField { id: impPath; implicitWidth: 300; placeholder: "~/Downloads/vpn.conf" }
            SetButton {
                label: "Import"; primary: true; enabled: impPath.text !== ""
                onClicked: {
                    var p = impPath.text.replace(/^~/, Quickshell.env("HOME"))
                    nm2.run([["nmcli", "connection", "import", "type", p.endsWith(".ovpn") ? "openvpn" : "wireguard", "file", p]])
                    page.importOpen = false
                }
            }
        }
    }
    Repeater {
        model: page.vpns
        delegate: SetRow {
            required property var modelData
            readonly property bool up: page.activeNames.indexOf(modelData.name) >= 0
            label: modelData.name
            hint: (modelData.type === "wireguard" ? "WireGuard" : "VPN") + (up ? " · connected" : "")
            SetButton { label: "Edit"; onClicked: Quickshell.execDetached(["nm-connection-editor", "--edit", modelData.uuid]) }
            SetToggle { checked: up; onToggled: v => nm.run([["nmcli", "connection", v ? "up" : "down", "id", modelData.name]]) }
        }
    }

    // ── General ──
    SetSection { text: "General" }
    SetRow {
        label: "DNS for all networks"
        hint: "Applies to every saved Wi-Fi and wired network"
        SetSelect {
            implicitWidth: 150
            readonly property var names: ["Per network", "Cloudflare", "Google", "Quad9"]
            options: names
            currentIndex: names.indexOf(page.dnsAll)
            onPicked: i => {
                var v = names[i]
                page.dnsAll = v
                var d = v === "Cloudflare" ? "1.1.1.1 1.0.0.1" : v === "Google" ? "8.8.8.8 8.8.4.4" : v === "Quad9" ? "9.9.9.9 149.112.112.112" : ""
                nm2.run([["sh", "-c", "nmcli -t -f NAME,TYPE connection show | grep -E ':(802-11-wireless|802-3-ethernet)$' | sed 's/:[^:]*$//' | while IFS= read -r n; do nmcli connection modify id \"$n\" ipv4.dns \"$1\" ipv4.ignore-auto-dns $2; done", "sh", d, d === "" ? "no" : "yes"]])
            }
        }
    }
    SetRow {
        label: "Proxy"
        hint: "For apps that follow the system proxy"
        SetSeg {
            options: ["None", "Manual", "Auto (PAC)"]
            current: page.proxyMode === "manual" ? "Manual" : page.proxyMode === "auto" ? "Auto (PAC)" : "None"
            onPicked: v => {
                var m = v === "Manual" ? "manual" : v === "Auto (PAC)" ? "auto" : "none"
                page.proxyMode = m
                nm2.run([["gsettings", "set", "org.gnome.system.proxy", "mode", m]])
            }
        }
    }
    SetRow {
        visible: page.proxyMode === "manual"
        label: "Proxy server"
        hint: "Used for HTTP and HTTPS"
        SetTextField { id: pxHost; implicitWidth: 170; placeholder: "host" }
        SetTextField { id: pxPort; implicitWidth: 70; placeholder: "port" }
        SetButton {
            label: "Apply"; primary: true; enabled: pxHost.text !== ""
            onClicked: nm2.run([["gsettings", "set", "org.gnome.system.proxy.http", "host", pxHost.text], ["gsettings", "set", "org.gnome.system.proxy.http", "port", pxPort.text || "8080"],
                                ["gsettings", "set", "org.gnome.system.proxy.https", "host", pxHost.text], ["gsettings", "set", "org.gnome.system.proxy.https", "port", pxPort.text || "8080"]])
        }
    }
    SetRow {
        visible: page.proxyMode === "auto"
        label: "PAC address"
        SetTextField { id: pxPac; implicitWidth: 260; placeholder: "http://…/proxy.pac" }
        SetButton { label: "Apply"; primary: true; enabled: pxPac.text !== ""; onClicked: nm2.run([["gsettings", "set", "org.gnome.system.proxy", "autoconfig-url", pxPac.text]]) }
    }
    SetRow {
        label: "Hostname"
        hint: "Asks for your password"
        SetTextField { id: hn; implicitWidth: 180; text: page.hostname; placeholder: "hostname" }
        SetButton { label: "Apply"; primary: true; enabled: hn.text !== "" && hn.text !== page.hostname; onClicked: nm2.run([["pkexec", "hostnamectl", "hostname", hn.text]]) }
    }
    SetRow {
        label: "Wi-Fi power saving"
        hint: "Saves battery, can add latency. Applies to every saved Wi-Fi network"
        SetSeg {
            options: ["Off", "Default", "On"]
            current: page.powerSave
            onPicked: v => {
                page.powerSave = v
                var n = v === "Off" ? "2" : v === "On" ? "3" : "0"
                nm2.run([["sh", "-c", "nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | sed 's/:[^:]*$//' | while IFS= read -r n; do nmcli connection modify id \"$n\" 802-11-wireless.powersave \"$1\"; done", "sh", n]])
            }
        }
    }

    // ── QR overlay ──
    Rectangle {
        parent: page
        visible: page.qrOpen
        anchors.fill: parent
        z: 50
        color: Theme.alpha("#000000", 0.6)
        MouseArea { anchors.fill: parent; onClicked: { page.qrOpen = false; nm2.run([["rm", "-f", Quickshell.env("HOME") + "/.cache/qs-wifi-qr.png"]]) } }
        Rectangle {
            anchors.centerIn: parent
            width: 300; height: 340
            radius: Theme.radius
            color: Theme.bgPanel
            border.width: 1
            border.color: Theme.accent
            Column {
                anchors.centerIn: parent
                spacing: 12
                Rectangle {
                    width: 240; height: 240; color: "white"; radius: 6
                    Image { anchors.fill: parent; anchors.margins: 6; source: page.qrSource; fillMode: Image.PreserveAspectFit; cache: false; smooth: false }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Scan with a phone camera"; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 11 }
                SetButton { anchors.horizontalCenter: parent.horizontalCenter; label: "Close"; onClicked: { page.qrOpen = false; nm2.run([["rm", "-f", Quickshell.env("HOME") + "/.cache/qs-wifi-qr.png"]]) } }
            }
        }
    }
}
