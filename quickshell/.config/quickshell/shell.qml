import Quickshell
import QtQuick

ShellRoot {
    VolumeOsd { id: volumeOsd }
    BrightnessOsd { id: brightnessOsd }
    ScreenshotOsd {}
    SettingsWindow { id: settingsWindow }
    Notifications { id: notifications }
    PowerMenu { id: powerMenu }
    Bar { id: bar }
    Wheel {}

    // Hand the live components to the Settings pages.
    Component.onCompleted: {
        Refs.bar = bar
        Refs.volumeOsd = volumeOsd
        Refs.brightnessOsd = brightnessOsd
        Refs.powerMenu = powerMenu
        Refs.notifications = notifications
        Refs.settings = settingsWindow
    }

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
