// Live Android Auto cluster map, decoded by the native ClusterVideo plugin
// (/etc/qml/ClusterVideo). Dashboard.qml loads this through a Loader, so a missing
// or broken plugin only means the map never appears; the NavCard still works.
//
// The phone draws the map mapWidth x mapHeight (the head unit reports it) centred in the
// video: Android Auto splits the announced margins evenly, so the wide 1280x720 stream has
// its 1280x480 map at y 120, not at the top. The crop matches the shape this item is shown
// at: the 800x476 band between the dials, or the whole 1920x720 panel in full-screen map mode.
import QtQuick 2.14
import ClusterVideo 1.0

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
    readonly property bool streaming: video.streaming

    // centred crop of the drawn map with the aspect ratio of the area it fills, in video pixels
    readonly property real aspect: full ? 1920 / 720 : 800 / 476
    readonly property rect crop: {
        var w = mapWidth, h = mapHeight
        var x0 = Math.round((videoSize.width - w) / 2), y0 = Math.round((videoSize.height - h) / 2)
        if (w / h > aspect) { var cw = Math.round(h * aspect); return Qt.rect(x0 + Math.round((w - cw) / 2), y0, cw, h) }
        var ch = Math.round(w / aspect)
        return Qt.rect(x0, y0 + Math.round((h - ch) / 2), w, ch)
    }

    ClusterVideoItem {
        id: video
        anchors.fill: parent
        host: map.host
        port: 8766
        sourceRect: map.crop
        visible: streaming
    }
}
