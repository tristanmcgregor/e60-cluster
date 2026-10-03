// Live Android Auto cluster map, decoded by the native ClusterVideo plugin
// (/etc/qml/ClusterVideo). Dashboard.qml loads this through a Loader, so a missing
// or broken plugin only means the map never appears; the NavCard still works.
import QtQuick 2.14
import ClusterVideo 1.0

Item {
    id: map

    property string host: ""
    readonly property bool streaming: video.streaming

    ClusterVideoItem {
        id: video
        anchors.fill: parent
        host: map.host
        port: 8766
        // full 800x480 frame (ClusterVideo.kt announces no margins)
        sourceRect: Qt.rect(0, 0, 800, 480)
        visible: streaming
    }

}
