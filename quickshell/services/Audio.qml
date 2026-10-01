pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.common

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real inputVolume: source?.audio?.volume ?? 0
    readonly property bool inputMuted: source?.audio?.muted ?? false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioSource)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)

    readonly property string icon: iconFor(root.volume, root.muted)

    // Fired when the output volume or mute changes, for the island's OSD.
    signal volumeTouched

    // Tracking a node binds its audio state live; per-app streams are only
    // needed while the Sound page shows their sliders.
    property int streamWatchers: 0

    PwObjectTracker {
        objects: [root.sink, root.source, ...(root.streamWatchers > 0 ? root.streams : [])]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged(): void {
            root.volumeTouched();
        }
        function onMutedChanged(): void {
            root.volumeTouched();
        }
    }

    function iconFor(volume: real, muted: bool): string {
        if (muted || volume <= 0)
            return Icons.volumeOff;
        if (volume < 0.34)
            return Icons.volumeLow;
        if (volume < 0.67)
            return Icons.volumeMedium;
        return Icons.volumeHigh;
    }

    function setNodeVolume(node: PwNode, v: real): void {
        if (!node?.audio)
            return;
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, v));
    }

    function setVolume(v: real): void {
        root.setNodeVolume(root.sink, v);
    }
    function setInputVolume(v: real): void {
        root.setNodeVolume(root.source, v);
    }
    function nudge(delta: real): void {
        root.setVolume(root.volume + delta);
    }

    function toggleMute(): void {
        if (root.sink?.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setDefault(node: PwNode): void {
        if (node.type === PwNodeType.AudioSource)
            Pipewire.preferredDefaultAudioSource = node;
        else
            Pipewire.preferredDefaultAudioSink = node;
    }

    function nodeName(node: PwNode): string {
        return node?.description || node?.nickname || node?.name || "";
    }

    function streamName(node: PwNode): string {
        const p = node?.properties ?? {};
        return p["application.name"] || node?.description || node?.name || "App";
    }

    function deviceIcon(node: PwNode): string {
        if (node?.type === PwNodeType.AudioSource)
            return Icons.microphone;
        const n = root.nodeName(node).toLowerCase();
        if (n.includes("hdmi") || n.includes("displayport"))
            return Icons.monitor;
        if (n.includes("headphone") || n.includes("headset") || n.includes("bluez") || n.includes("airpods"))
            return Icons.headphones;
        return Icons.volumeMedium;
    }
}
