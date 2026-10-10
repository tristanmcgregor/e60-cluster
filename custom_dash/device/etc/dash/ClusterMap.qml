// Live Android Auto cluster map, decoded by the native ClusterVideo plugin. Each release
// carries its own copy of the plugin (ClusterVideo/ next to this file, VideoLocal.qml), so
// an over-the-air update can fix it; if that copy will not load, the one installed from USB
// (/etc/qml/ClusterVideo, VideoSystem.qml) is used. Dashboard.qml loads this through a
// Loader, so no working plugin at all only means the map never appears; the NavCard works.
//
// The phone draws the map mapWidth x mapHeight (the head unit reports it) centred in the
// video: Android Auto splits the announced margins evenly, so the wide 1280x720 stream has
// its 1280x480 map at y 120, not at the top. The crop matches the shape this item is shown
// at: the 800x476 band between the dials, or in full-screen map mode the area below the status
// row, sized by Dashboard.qml to the map's own shape so nothing is cut off.
import QtQuick 2.14

Item {
    id: map

    property string host: ""
    property int mapWidth: 800
    property int mapHeight: 480
    // size of the whole video; 0 = not reported (older head unit builds), then the smallest
    // Android Auto video size that holds the map (800x480, 1280x720, 1920x1080)
    property int videoWidth: 0
    property int videoHeight: 0
    readonly property size videoSize: {
        if (videoWidth >= mapWidth && videoHeight >= mapHeight) return Qt.size(videoWidth, videoHeight)
        var sizes = [[800, 480], [1280, 720], [1920, 1080]]
        for (var i = 0; i < sizes.length; i++)
            if (sizes[i][0] >= mapWidth && sizes[i][1] >= mapHeight) return Qt.size(sizes[i][0], sizes[i][1])
        return Qt.size(mapWidth, mapHeight)
    }
    property bool full: false
    // Android Auto only sends a frame when the picture changes, so a still map (stopped at
    // lights) can go quiet for a while. The plugin's own "streaming" drops after 2 s without a
    // frame, which hid the map (and left full-screen map mode) until the next one. Keep the
    // last picture up while connected, and only give up after idleMs without a frame.
    property int idleMs: 15000
    property bool hasPicture: false
    readonly property bool streaming: hasPicture && video.status === Loader.Ready && video.item.connected
    Connections {
        target: video.item
        ignoreUnknownSignals: true
        onFramesDecodedChanged: { map.hasPicture = true; idle.restart() }
        onConnectedChanged: if (!video.item.connected) map.hasPicture = false
    }
    Timer { id: idle; interval: map.idleMs; onTriggered: map.hasPicture = false }

    // centred crop of the drawn map with the aspect ratio of the area it fills, in video pixels
    readonly property real aspect: width > 0 && height > 0 ? width / height : (full ? 1920 / 720 : 800 / 476)
    readonly property rect crop: {
        var w = mapWidth, h = mapHeight
        var x0 = Math.round((videoSize.width - w) / 2), y0 = Math.round((videoSize.height - h) / 2)
        if (w / h > aspect) { var cw = Math.round(h * aspect); return Qt.rect(x0 + Math.round((w - cw) / 2), y0, cw, h) }
        var ch = Math.round(w / aspect)
        return Qt.rect(x0, y0 + Math.round((h - ch) / 2), w, ch)
    }

    Loader {
        id: video
        anchors.fill: parent
        source: "VideoLocal.qml"
        visible: map.streaming
        onStatusChanged: {
            if (status !== Loader.Error) return
            if (source.toString().indexOf("VideoLocal.qml") >= 0) {
                console.warn("[dash] this release's map plugin did not load; using the installed one")
                source = "VideoSystem.qml"
            }
        }
        onLoaded: {
            item.host = Qt.binding(function() { return map.host })
            item.sourceRect = Qt.binding(function() { return map.crop })
            item.port = 8766
        }
    }
}
