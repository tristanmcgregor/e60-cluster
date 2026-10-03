import QtQuick 2.12
import QtQuick.Window 2.12
import ClusterVideo 1.0
Window {
    width: 520; height: 480; visible: true
    ClusterVideoItem { id: v; anchors.fill: parent; host: "127.0.0.1"; port: 8766; sourceRect: Qt.rect(140, 0, 520, 480) }
    Timer { interval: 4000; running: true; onTriggered: {
        console.log("connected", v.connected, "streaming", v.streaming, "frames", v.framesDecoded)
        v.grabToImage(function(r) { r.saveToFile("/tmp/cv_test.png"); Qt.quit() }) } }
}
