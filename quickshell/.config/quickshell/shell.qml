import Quickshell
import QtQuick

ShellRoot {
    VolumeOsd { id: volumeOsd }
    BrightnessOsd { id: brightnessOsd }
    ScreenshotOsd {}
    SettingsWindow {}
    Notifications {}
    PowerMenu {}
    Bar {}
    Wheel {}

    // The volume and brightness popups share one spot: showing either replaces the other.
    Connections {
        target: volumeOsd
        function onShowingChanged() { if (volumeOsd.showing) brightnessOsd.showing = false }
    }
    Connections {
        target: brightnessOsd
        function onShowingChanged() { if (brightnessOsd.showing) volumeOsd.dismiss() }
    }
}
