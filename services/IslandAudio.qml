pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia.Config
import "../modules/dashboard/helpers/AudioLogic.js" as Logic

// One shared monitor per playback node, regardless of the number of screens.
Singleton {
    id: root
    readonly property bool enabled: GlobalConfig.dashboard.enabled
    property PwNode sink: Audio.sink
    property var audibleStreams: []
    property var held: ({})
    readonly property bool sinkSilenced: !root.sink?.audio || root.sink.audio.muted || root.sink.audio.volume <= 0
    readonly property bool audible: audibleStreams.length > 0
    readonly property string label: audibleStreams.map(s => s.label).filter((name, i, names) => names.indexOf(name) === i).join(" + ")
    // Don't attach an unrelated (or paused) browser session to another app's audio.
    readonly property var player: Players.list.find(p => audibleStreams.some(s => Logic.matchesPlayer(p, s.properties))) ?? null

    PwNodeLinkTracker { id: links; node: root.enabled ? root.sink : null }
    PwObjectTracker { objects: [root.sink, ...links.linkGroups, ...links.linkGroups.map(g => g.source)].filter(n => n) }
    Instantiator {
        id: monitors
        model: links.linkGroups
        delegate: QtObject {
            id: watcher
            required property var modelData
            property double until: 0
            readonly property var source: modelData.source
            readonly property bool silenced: !!source?.audio && (source.audio.muted || source.audio.volume <= 0)
            // No channel positions (Spotify): Quickshell's peak monitor can't match the capture stream and reads silence.
            readonly property bool blind: !!source?.audio && source.audio.channels.length > 0 && source.audio.channels.every(channel => channel === PwAudioChannel.Unknown)
            readonly property bool eligible: root.enabled && modelData.state === PwLinkState.Active && source?.isStream && !!source?.audio && !silenced && !root.sinkSilenced
            readonly property PwNodePeakMonitor meter: PwNodePeakMonitor {
                node: watcher.source
                enabled: watcher.eligible
                // Remember short sounds that fall between the 100 ms UI samples.
                onPeakChanged: watcher.until = Logic.audibleUntil(watcher.until, peak, watcher.eligible, Date.now())
            }
        }
    }
    function sample(): void {
        const current = [];
        const silenced = [];
        const now = Date.now();
        for (let i = 0; i < monitors.count; ++i) {
            const monitor = monitors.objectAt(i);
            const source = monitor?.source;
            if (!source) continue;
            monitor.until = Logic.audibleUntil(monitor.until, monitor.meter.peak, monitor.eligible, now);
            const properties = source.properties;
            const key = Logic.streamKey(properties);
            if (monitor.silenced) silenced.push(key);
            // The peak monitor can't hear blind streams, so trust a matching MPRIS player that is playing.
            const heard = monitor.until > now || (monitor.blind && monitor.eligible && Players.list.some(p => Logic.matchesPlayer(p, properties)));
            if (heard) current.push({ key: key, stream: { label: Logic.streamLabel(properties) || Audio.getStreamName(source), properties: properties } });
        }
        // A seek makes the browser drop and recreate its stream; carry it across the gap instead of blinking.
        const carried = Logic.carryOver(held, current, silenced, sinkSilenced, now);
        held = carried.held;
        // Refresh metadata as well as activity, but avoid notifying every 100 ms.
        if (JSON.stringify(carried.streams) !== JSON.stringify(audibleStreams)) audibleStreams = carried.streams;
    }
    onEnabledChanged: if (!enabled) { audibleStreams = []; held = {}; }
    Timer { interval: 100; repeat: true; running: root.enabled; onTriggered: root.sample() }
    IpcHandler {
        target: "islandAudio"
        function status(): string {
            return JSON.stringify({ audible: root.audible, label: root.label, streams: root.audibleStreams.map(s => ({ app: s.properties["application.name"] || "", media: s.properties["media.title"] || s.properties["media.name"] || "" })) });
        }
    }
}
