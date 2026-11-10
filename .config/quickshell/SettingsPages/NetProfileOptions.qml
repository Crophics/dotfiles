import QtQuick
import Quickshell.Io
import "../"

// The per-connection options of a NetworkManager profile (auto-connect, IP, DNS, metered,
// MAC, priority / MTU). Reads the profile with nmcli, writes each change straight back.
Column {
    id: o
    property string profile: ""
    property bool wifi: true
    property bool active: false          // re-activate after a change that needs it
    signal changed()

    width: parent ? parent.width : 0
    spacing: 10

    property bool autoconnect: true
    property string metered: "unknown"
    property int priority: 0
    property string method: "auto"
    property string address: ""
    property string gateway: ""
    property string dns: ""
    property string mac: "preserve"
    property string mtu: "0"
    property bool customDns: false
    property string error: nm.error

    readonly property var dnsPresets: ({ "Cloudflare": "1.1.1.1,1.0.0.1", "Google": "8.8.8.8,8.8.4.4", "Quad9": "9.9.9.9,149.112.112.112" })
    readonly property string dnsNorm: dns.replace(/[\s;]+/g, ",").replace(/,+/g, ",").replace(/^,|,$/g, "")
    readonly property string dnsChoice: {
        if (customDns) return "Custom"
        if (dnsNorm === "") return "Router"
        for (var k in dnsPresets) if (dnsPresets[k] === dnsNorm) return k
        return "Custom"
    }

    function load() {
        if (profile === "") return
        pRead.command = ["nmcli", "-g",
            "connection.autoconnect,connection.metered,connection.autoconnect-priority,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,"
            + (wifi ? "802-11-wireless.cloned-mac-address" : "802-3-ethernet.mtu"),
            "connection", "show", "id", profile]
        pRead.running = true
    }
    onProfileChanged: { customDns = false; load() }

    // Apply nmcli property pairs, then re-activate when the connection is up.
    function mod(args, reup) {
        var cmds = [["nmcli", "connection", "modify", "id", profile].concat(args)]
        if (reup && active) cmds.push(["nmcli", "connection", "up", "id", profile])
        nm.run(cmds)
    }
    function setDns(v) {
        customDns = false
        mod(v === "" ? ["ipv4.dns", "", "ipv4.ignore-auto-dns", "no"] : ["ipv4.dns", v.replace(/,/g, " "), "ipv4.ignore-auto-dns", "yes"], true)
        dns = v
    }

    NmRun { id: nm; onFinished: ok => { if (!ok) o.load(); o.changed() } }

    Process {
        id: pRead
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n")
                o.autoconnect = l[0] === "yes"
                o.metered = l[1] || "unknown"
                o.priority = parseInt(l[2]) || 0
                o.method = l[3] || "auto"
                o.address = (l[4] || "").split(",")[0].trim()
                o.gateway = l[5] || ""
                o.dns = l[6] || ""
                if (o.wifi) o.mac = l[7] || "preserve"; else o.mtu = l[7] || "0"
            }
        }
    }

    SetSub {
        label: "Connect automatically"
        SetToggle { checked: o.autoconnect; onToggled: v => { o.autoconnect = v; o.mod(["connection.autoconnect", v ? "yes" : "no"], false) } }
    }

    SetSub {
        label: "IP address"
        hint: "Manual lets you set address, gateway and DNS"
        SetSeg {
            options: o.wifi ? ["Auto (DHCP)", "Manual"] : ["Auto (DHCP)", "Manual", "Link-local"]
            current: o.method === "manual" ? "Manual" : o.method === "link-local" ? "Link-local" : "Auto (DHCP)"
            onPicked: v => {
                var m = v === "Manual" ? "manual" : v === "Link-local" ? "link-local" : "auto"
                o.method = m
                if (m !== "manual") o.mod(["ipv4.method", m, "ipv4.addresses", "", "ipv4.gateway", ""], true)
            }
        }
    }
    SetSub {
        visible: o.method === "manual"
        label: "Address"
        hint: "With prefix, like 192.168.1.50/24"
        SetTextField { id: fAddr; implicitWidth: 200; text: o.address; placeholder: "192.168.1.50/24" }
    }
    SetSub {
        visible: o.method === "manual"
        label: "Gateway"
        SetTextField { id: fGw; implicitWidth: 200; text: o.gateway; placeholder: "192.168.1.1" }
        SetButton {
            label: "Apply"; primary: true
            enabled: fAddr.text.indexOf("/") > 0
            onClicked: o.mod(["ipv4.method", "manual", "ipv4.addresses", fAddr.text, "ipv4.gateway", fGw.text], true)
        }
    }

    SetSub {
        label: "DNS"
        SetSeg {
            options: ["Router", "Cloudflare", "Google", "Quad9", "Custom"]
            current: o.dnsChoice
            onPicked: v => {
                if (v === "Router") o.setDns("")
                else if (v === "Custom") { o.customDns = true }
                else o.setDns(o.dnsPresets[v])
            }
        }
    }
    SetSub {
        visible: o.dnsChoice === "Custom"
        label: "Servers"
        hint: "Separate with commas"
        SetTextField { id: fDns; implicitWidth: 200; text: o.dnsNorm; placeholder: "1.1.1.1, 9.9.9.9" }
        SetButton { label: "Apply"; primary: true; onClicked: o.setDns(fDns.text.replace(/[\s;]+/g, ",")); }
    }

    SetSub {
        label: "Metered connection"
        hint: "Limits background downloads and updates"
        SetSeg {
            options: ["Auto", "Yes", "No"]
            current: o.metered === "yes" ? "Yes" : o.metered === "no" ? "No" : "Auto"
            onPicked: v => { var m = v === "Yes" ? "yes" : v === "No" ? "no" : "unknown"; o.metered = m; o.mod(["connection.metered", m], false) }
        }
    }

    SetSub {
        visible: o.wifi
        label: "MAC address"
        hint: "Random hides your device from the network"
        SetSeg {
            options: ["Hardware", "Per network", "Always random"]
            current: o.mac === "random" ? "Always random" : o.mac === "stable" ? "Per network" : o.mac === "permanent" ? "Hardware" : "Hardware"
            onPicked: v => { var m = v === "Always random" ? "random" : v === "Per network" ? "stable" : "permanent"; o.mac = m; o.mod(["802-11-wireless.cloned-mac-address", m], true) }
        }
    }
    SetSub {
        visible: o.wifi
        label: "Priority"
        hint: "Higher joins first when several are in range"
        SetSeg {
            options: ["Low", "Normal", "High"]
            current: o.priority < 0 ? "Low" : o.priority > 0 ? "High" : "Normal"
            onPicked: v => { var p = v === "Low" ? -10 : v === "High" ? 10 : 0; o.priority = p; o.mod(["connection.autoconnect-priority", String(p)], false) }
        }
    }
    SetSub {
        visible: !o.wifi
        label: "MTU"
        hint: "0 = automatic"
        SetTextField { id: fMtu; implicitWidth: 100; text: o.mtu; placeholder: "0" }
        SetButton { label: "Apply"; primary: true; onClicked: o.mod(["802-3-ethernet.mtu", fMtu.text === "" ? "0" : fMtu.text], true) }
    }

    Text {
        visible: o.error !== ""
        width: parent.width
        text: o.error
        wrapMode: Text.WordWrap
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }
}
