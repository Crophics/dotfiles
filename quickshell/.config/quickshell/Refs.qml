pragma Singleton
import QtQuick

// Handles to the live shell components, filled in by shell.qml. The Settings pages
// read and write these directly, so a change applies instantly and there is only one
// copy of every setting.
QtObject {
    property var bar: null
    property var volumeOsd: null
    property var brightnessOsd: null
    property var powerMenu: null
    property var settings: null
}
