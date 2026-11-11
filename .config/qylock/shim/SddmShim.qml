// SddmShim.qml - gives the sign-in theme the same API a real SDDM greeter has
// (sddm.login / reboot / powerOff / suspend, userModel, sessionModel, keyboard),
// so the theme runs unchanged as the lock screen. Password only (no fingerprint reader).
// Trimmed from the 43pr qylock shim.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: shim

    property bool armed: false      // set by lock_shell once the lock is secure
    property bool unlocked: false   // guards against a double unlock

    // ── user model: just the current user ─────────────────────────────────
    property var userModel: ListModel {
        id: internalUserModel
        property string lastUser: Quickshell.env("USER") || "user"
        property int lastIndex: 0
        function rowCount() { return count; }
        function index(row, col) { return row; }
        function data(row, role) {
            var item = get(row);
            if (!item) return "";
            if (role === (Qt.UserRole + 1)) return item.name;
            if (role === (Qt.UserRole + 2)) return item.realName;
            return item.name;
        }
        Component.onCompleted: append({ name: lastUser, realName: lastUser, icon: "", homeDir: "/home/" + lastUser })
    }

    // Full name (GECOS) for the greeting, like SDDM shows it.
    Process {
        id: realNameFetcher
        command: ["bash", "-c", "getent passwd \"$(whoami)\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var full = this.text.trim();
                if (full.length > 0 && internalUserModel.count > 0)
                    internalUserModel.setProperty(0, "realName", full);
            }
        }
    }

    // ── session model: only the running session (switching makes no sense when locked) ──
    property var sessionModel: ListModel {
        property int lastIndex: 0
        function rowCount() { return count; }
        function index(row, col) { return row; }
        function data(row, role) { var item = get(row); return item ? item.name : ""; }
        Component.onCompleted: append({ name: "Hyprland", file: "hyprland.desktop" })
    }

    // ── the SDDM object the theme talks to ─────────────────────────────────
    property var sddm: QtObject {
        property string hostName: "archbtw"
        readonly property bool inLock: true   // the theme checks this to play the lock's unlock animation
        // suspend.sh: the screen is off and the laptop is about to sleep, so skip the fade-in
        readonly property bool instant: Quickshell.env("QYLOCK_INSTANT") === "1"
        signal loginFailed()
        signal loginSucceeded()

        function login(user, password, sessionIndex) {
            if (!shim.armed || shim.unlocked || password === "") {
                shim.sddm.loginFailed();
                return;
            }
            pam.pendingPassword = password;
            if (pam.active) {
                if (pam.responseRequired) pam.feed();
                return;
            }
            pam.user = Quickshell.env("USER") || "";
            if (!pam.start()) {
                console.warn("qylock: pam.start() failed");
                pam.pendingPassword = "";
                shim.sddm.loginFailed();
            }
        }

        function reboot()   { Quickshell.execDetached(["systemctl", "reboot"]); }
        function powerOff() { Quickshell.execDetached(["systemctl", "poweroff"]); }
        function suspend()  { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/qylock/suspend.sh"]); }
    }

    // The theme sets keyboard.numLock; give it something to set.
    property var keyboard: QtObject {
        property bool numLock: false
        property bool capsLock: false
    }

    // ── PAM: one conversation per attempt ──────────────────────────────────
    PamContext {
        id: pam
        property string pendingPassword: ""
        config: "qylock-pw"
        configDirectory: Quickshell.shellDir + "/assets/pam"

        function feed() {
            respond(pendingPassword);
            pendingPassword = "";
        }
        onResponseRequiredChanged: if (responseRequired && pendingPassword !== "") feed()

        onCompleted: (result) => {
            pendingPassword = "";
            if (shim.unlocked) return;
            if (result === PamResult.Success && shim.armed) {
                shim.unlocked = true;
                shim.sddm.loginSucceeded();
            } else {
                shim.sddm.loginFailed();
            }
        }
        onError: (error) => {
            console.warn("qylock: PAM error", error);
            pendingPassword = "";
            if (!shim.unlocked) shim.sddm.loginFailed();
        }
    }

    function resetAuth() {
        pam.pendingPassword = "";
        pam.abort();
        shim.unlocked = false;
    }

    Component.onCompleted: realNameFetcher.running = true
}
