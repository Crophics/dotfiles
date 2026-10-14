import QtQuick
import Quickshell.Services.Pipewire
import "../"

// Output and input devices, their volume, and the volume of each app that is playing sound.
SetPage {
    id: page
    title: "AUDIO"

    PwObjectTracker { objects: Pipewire.nodes.values }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)

    function name(n, fallback) { return n ? (n.description || n.nickname || n.name || fallback) : fallback }
    function pct(v) { return Math.round(v * 100) + "%" }

    SetSection { text: "Output" }
    SetRow {
        label: "Volume"
        SetSlider {
            from: 0; to: 1; step: 0.01
            displayText: page.pct(value)
            value: page.sink?.audio?.volume ?? 0
            onMoved: v => { if (page.sink?.audio) { page.sink.audio.muted = false; page.sink.audio.volume = v } }
        }
    }
    SetRow {
        label: "Mute"
        SetToggle { checked: page.sink?.audio?.muted ?? false; onToggled: v => { if (page.sink?.audio) page.sink.audio.muted = v } }
    }
    SetRow {
        label: "Device"
        SetSelect {
            implicitWidth: 320
            listWidth: 480
            options: page.sinks.map(n => page.name(n, "Output"))
            currentIndex: page.sinks.findIndex(n => n.id === page.sink?.id)
            onPicked: i => Pipewire.preferredDefaultAudioSink = page.sinks[i]
        }
    }

    SetSection { text: "Input" }
    SetRow {
        label: "Volume"
        SetSlider {
            from: 0; to: 1; step: 0.01
            displayText: page.pct(value)
            value: page.source?.audio?.volume ?? 0
            onMoved: v => { if (page.source?.audio) { page.source.audio.muted = false; page.source.audio.volume = v } }
        }
    }
    SetRow {
        label: "Mute"
        SetToggle { checked: page.source?.audio?.muted ?? false; onToggled: v => { if (page.source?.audio) page.source.audio.muted = v } }
    }
    SetRow {
        label: "Device"
        SetSelect {
            implicitWidth: 320
            listWidth: 480
            options: page.sources.map(n => page.name(n, "Input"))
            currentIndex: page.sources.findIndex(n => n.id === page.source?.id)
            onPicked: i => Pipewire.preferredDefaultAudioSource = page.sources[i]
        }
    }

    SetSection { text: "Apps" }
    Repeater {
        model: page.streams
        delegate: SetRow {
            required property var modelData
            label: page.name(modelData, "App")
            SetSlider {
                from: 0; to: 1; step: 0.01
                displayText: page.pct(value)
                value: modelData.audio?.volume ?? 0
                onMoved: v => { if (modelData.audio) { modelData.audio.muted = false; modelData.audio.volume = v } }
            }
        }
    }
    Text {
        visible: page.streams.length === 0
        text: "No app is playing sound right now."
        color: Theme.textFaint
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
