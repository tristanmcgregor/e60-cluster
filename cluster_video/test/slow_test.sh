#!/bin/bash
# A dash that draws far slower than the video: frames must be replaced, not queued (flat memory).
CV=/Users/tritty/Documents/code/JLY/cluster_video; B=$HOME/cvtest; cd $B
python3 $CV/test/fake_stream.py test.h264 & SRV=$!
sleep 1
cat > slow.qml <<Q
import QtQuick 2.14
import ClusterVideo 1.0
Rectangle {
    width: 800; height: 480
    ClusterVideoItem { anchors.fill: parent; host: "127.0.0.1" }
    // the GUI thread is busy 300 ms of every 330 ms: about 3 frames drawn per second of 30 sent
    Timer { interval: 30; repeat: true; running: true
        onTriggered: { var t = Date.now(); while (Date.now() - t < 300) {} } }
}
Q
QT_QUICK_BACKEND=software QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH=$B /usr/lib/x86_64-linux-gnu/qt5/bin/qmlscene slow.qml > slow.log 2>&1 & Q=$!
for s in 5 15 25; do sleep $((s == 5 ? 5 : 10)); echo "after ${s}s: $(grep VmRSS /proc/$Q/status)"; done
kill $Q $SRV; grep clustervideo slow.log | tail -3
