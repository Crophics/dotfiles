// lock_shell.qml - qylock in-session Wayland lock, trimmed from Ryoku's copy.
//
// Covers every output with a secure session lock (WlSessionLock) and loads the
// selected qylock theme (default clockwork/orbital) on top. SddmShim does the
// password / fingerprint PAM conversations; on success the lock is released.
//
// Ryoku's proof/handshake with its shell daemon is dropped: lock.sh only needs
// to know when the lock is secure (a marker file, so suspend can wait for it).

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./shim"

ShellRoot {
    id: shellRoot

    property string activeTheme: Quickshell.env("QS_THEME") || "clockwork/orbital"
    property string themePath: Quickshell.env("QS_THEME_PATH") || (Quickshell.shellDir + "/themes/" + activeTheme)

    // The shim exposes SDDM's API (sddm, config, userModel, ...) to the theme.
    readonly property var sddm: sddmShim.sddm
    readonly property var config: sddmShim.config
    readonly property var userModel: sddmShim.userModel
    readonly property var sessionModel: sddmShim.sessionModel
    readonly property var keyboard: sddmShim.keyboard
    property bool sessionLocked: true
    property bool lockSecure: false
    readonly property string markerPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qylock.locked"

    SddmShim {
        id: sddmShim
        themePath: shellRoot.themePath
    }

    // lock.sh --wait polls this file: it exists only while the lock is covering
    // every output.
    Process {
        id: marker
        function set(on) {
            command = on ? ["touch", shellRoot.markerPath] : ["rm", "-f", shellRoot.markerPath]
            running = true
        }
    }

    // Authentication may arm only while the lock is secure.
    Connections {
        target: sddmShim.sddm
        function onLoginSucceeded() {
            if (!shellRoot.lockSecure || !sddmShim.loginSessionActive)
                return
            unlockTimer.start()
        }
    }
    Connections {
        target: sddmShim
        function onLoginSessionActiveChanged() {
            if (sddmShim.loginSessionActive) {
                if (shellRoot.lockSecure) {
                    sddmShim.armWhenReady = true
                    sddmShim.sddm.surfaceRevealed()
                }
                return
            }
            unlockTimer.stop()
            sddmShim.armWhenReady = false
            sddmShim.resetAuth()
        }
    }

    // Short pause so the theme can play its unlock animation, then release.
    Timer {
        id: unlockTimer
        interval: 150
        onTriggered: {
            marker.set(false)
            shellRoot.sessionLocked = false
            quitTimer.start()
        }
    }
    Timer {
        id: quitTimer
        interval: 250
        onTriggered: Qt.quit()
    }

    Component {
        id: themeComponent
        Loader {
            anchors.fill: parent
            source: "file://" + shellRoot.themePath + "/Main.qml"
            onLoaded: item.forceActiveFocus()
            onStatusChanged: {
                if (status === Loader.Error)
                    console.error("FAILED to load theme:", source)
            }
        }
    }

    // Fingerprint reader drawn above any theme; it only displays shim state.
    property color fpAccent: "#e8e8e8"
    Component {
        id: fpOverlayComponent
        Item {
            id: ov
            anchors.fill: parent
            z: 10000
            readonly property var s: sddmShim.sddm
            readonly property string ph: !s.fingerprintReady ? "off"
                : (s.fingerprintState === "idle" ? "ready" : s.fingerprintState)
            readonly property bool unavailable: s.fingerprintState === "unavailable"

            FingerprintScan {
                id: fpScan
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.60
                sizePx: Math.round(Math.min(parent.width, parent.height) * 0.10)
                accent: shellRoot.fpAccent
                phase: ov.unavailable ? "off" : ov.ph
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: fpScan.bottom
                anchors.topMargin: Math.round(fpScan.sizePx * 0.18)
                font.pixelSize: Math.round(fpScan.sizePx * 0.18)
                color: ov.ph === "fail" ? "#e0806f" : shellRoot.fpAccent
                opacity: (ov.unavailable || ov.ph === "scanning" || ov.ph === "success" || ov.ph === "fail") ? 0.92 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                text: ov.unavailable ? qsTr("Fingerprint unavailable — use your password")
                    : ov.ph === "success" ? qsTr("Unlocked")
                    : (ov.ph === "fail" ? qsTr("Not recognized") : qsTr("Reading…"))
                visible: opacity > 0.01
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: shellRoot.sessionLocked

        onSecureChanged: {
            shellRoot.lockSecure = lock.secure
            if (lock.secure) {
                marker.set(true)
                if (sddmShim.loginSessionActive) {
                    sddmShim.armWhenReady = true
                    sddmShim.sddm.surfaceRevealed()
                }
            } else {
                sddmShim.armWhenReady = false
                sddmShim.resetAuth()
            }
        }

        surface: Component {
            WlSessionLockSurface {
                color: "black"

                // Swallow scroll / pinch so nothing leaks to the desktop.
                PinchHandler { target: null }
                WheelHandler { target: null }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    hoverEnabled: true
                    onWheel: (wheel) => { wheel.accepted = true }
                }

                Loader { anchors.fill: parent; sourceComponent: themeComponent }
                Loader { anchors.fill: parent; sourceComponent: fpOverlayComponent }
            }
        }
    }
}
