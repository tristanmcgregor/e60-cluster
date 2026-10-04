// Live Android Auto cluster map, decoded by the native ClusterVideo plugin
// (/etc/qml/ClusterVideo). Dashboard.qml loads this through a Loader, so a missing
// or broken plugin only means the map never appears; the NavCard still works.
//
// The phone draws the map at the top-left of the video, mapWidth x mapHeight (the head unit
// reports it). The crop matches the shape this item is shown at: the 800x476 band between
// the dials, or the whole 1920x720 panel in full-screen map mode.
import QtQuick 2.14
import ClusterVideo 1.0

Item {
    id: map

    property string host: ""
    property int mapWidth: 800
    property int mapHeight: 480
    property bool full: false
    readonly property bool streaming: video.streaming

    // centred crop of the drawn map with the aspect ratio of the area it fills
    readonly property real aspect: full ? 1920 / 720 : 800 / 476
    readonly property rect crop: {
        var w = mapWidth, h = mapHeight
        if (w / h > aspect) { var cw = Math.round(h * aspect); return Qt.rect(Math.round((w - cw) / 2), 0, cw, h) }
        var ch = Math.round(w / aspect)
        return Qt.rect(0, Math.round((h - ch) / 2), w, ch)
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
