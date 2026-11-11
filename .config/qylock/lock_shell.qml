// lock_shell.qml - qylock: the session lock screen, drawn by Quickshell.
//
// Covers every screen with a secure session lock (WlSessionLock) and loads the sign-in
// theme (QS_THEME_PATH, set by lock.sh) on top. SddmShim checks the password with PAM;
// on success the theme plays its unlock fade and the lock is released.
// Trimmed from the 43pr qylock (no fingerprint, no theme picker).

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./shim"

ShellRoot {
    id: shellRoot

    property string themePath: Quickshell.env("QS_THEME_PATH") || ""

    // The shim exposes SDDM's API to the theme (the theme looks these names up).
    readonly property var sddm: sddmShim.sddm
    readonly property var userModel: sddmShim.userModel
    readonly property var sessionModel: sddmShim.sessionModel
    readonly property var keyboard: sddmShim.keyboard
    readonly property var config: ({})

    property bool sessionLocked: true
    property bool lockSecure: false
    // "Ready" = Hyprland confirmed the lock AND every screen's lock surface has drawn a few
    // frames. Only then does the marker file appear (lock.sh --wait), so the laptop never
    // sleeps with a blank lock surface (on wake the desktop would show until it drew).
    property int surfacesReady: 0
    function checkReady() {
        if (lockSecure && surfacesReady >= Quickshell.screens.length)
            marker.set(true)
    }
    onSurfacesReadyChanged: checkReady()
    readonly property string markerPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qylock.locked"

    SddmShim { id: sddmShim }

    Process {
        id: marker
        function set(on) {
            command = on ? ["touch", shellRoot.markerPath] : ["rm", "-f", shellRoot.markerPath]
            running = true
        }
    }

    Connections {
        target: sddmShim.sddm
        function onLoginSucceeded() {
            if (shellRoot.lockSecure) unlockTimer.start()
        }
    }

    // Let the theme's unlock fade (about 300 ms) finish, then release the lock.
    Timer {
        id: unlockTimer
        interval: 320
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
            // true once the theme has loaded and finished fading in
            readonly property bool settled: item !== null && (item.ui1 === undefined || item.ui1 >= 0.99)
            anchors.fill: parent
            source: "file://" + shellRoot.themePath + "/Main.qml"
            onLoaded: item.forceActiveFocus()
            onStatusChanged: if (status === Loader.Error) console.error("qylock: FAILED to load theme:", source)
        }
    }

    WlSessionLock {
        id: lock
        locked: shellRoot.sessionLocked

        onSecureChanged: {
            shellRoot.lockSecure = lock.secure
            sddmShim.armed = lock.secure
            if (lock.secure) shellRoot.checkReady()
            else sddmShim.resetAuth()
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

                Item {
                    id: drawn
                    property int frames: 0
                    property bool counted: false
                    Connections {
                        target: drawn.Window.window
                        function onFrameSwapped() {
                            if (!(themeHost.item && themeHost.item.settled)) return
                            drawn.frames++
                            // instant lock (screen off for suspend): Hyprland draws no frames on a
                            // switched-off screen, so the first finished frame has to count
                            if (!drawn.counted && drawn.frames >= (shellRoot.sddm.instant ? 1 : 4)) {
                                drawn.counted = true
                                shellRoot.surfacesReady++
                            }
                        }
                    }
                }
                // Hyprland takes the keyboard away from the lock about half a second after waking
                // from suspend and doesn't give it back (you had to click first). To be safe
                // every new surface checks right away too. When the keyboard is missing, refocus.sh
                // clicks an empty spot of the lock (Hyprland only hands the keyboard over on a click).
                // Stops as soon as the password box has focus; at most 3 tries.
                Item {
                    id: refocus
                    property int tries: 0
                    Component.onCompleted: refocusTimer.restart()
                    Connections {
                        target: refocus.Window.window
                        function onActiveChanged() {
                            if (!refocus.Window.window.active && shellRoot.sessionLocked) { refocus.tries = 0; refocusTimer.restart() }
                        }
                    }
                    Timer {
                        id: refocusTimer
                        interval: 400
                        onTriggered: {
                            // themeHost holds themeComponent (a Loader), whose item is the theme
                            const theme = themeHost.item ? themeHost.item.item : null
                            const typing = theme && theme.pwdHasFocus === true
                            if (!shellRoot.sessionLocked || typing || refocus.tries >= 3) return
                            refocus.tries++
                            nudge.running = true
                            refocusTimer.restart()   // check again; click once more if the box still has no focus
                        }
                    }
                    Process {
                        id: nudge
                        command: [Quickshell.env("HOME") + "/.config/qylock/refocus.sh"]
                    }
                }
                Loader { id: themeHost; anchors.fill: parent; sourceComponent: themeComponent }
            }
        }
    }
}
