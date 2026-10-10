#!/bin/bash
# ClusterMap.qml: loads the release's own plugin copy (VideoLocal), falls back to /etc/qml (VideoSystem).
set -e
DASH=/Users/tritty/Documents/code/JLY/custom_dash/device/etc/dash
T=/tmp/maptest; rm -rf $T; mkdir -p $T/etc/dashv/9 $T/etc/dashv/10 $T/sys
cp $DASH/ClusterMap.qml $DASH/VideoLocal.qml $DASH/VideoSystem.qml $T/etc/dashv/9/
cp $DASH/ClusterMap.qml $DASH/VideoLocal.qml $DASH/VideoSystem.qml $T/etc/dashv/10/
cp -r $HOME/cvtest/ClusterVideo $T/etc/dashv/9/ClusterVideo; echo "plugin clustervideo" > $T/etc/dashv/9/ClusterVideo/qmldir
cp -r $HOME/cvtest/ClusterVideo $T/sys/ClusterVideo
# release 10: broken own copy -> must fall back to the installed one
mkdir $T/etc/dashv/10/ClusterVideo; echo "plugin clustervideo" > $T/etc/dashv/10/ClusterVideo/qmldir
cat > $T/main.qml <<Q
import QtQuick 2.14
Item {
  property var maps: []
  function load(u) { var c = Qt.createComponent(u); if (c.status !== Component.Ready) { console.log(u, c.errorString()); return }
    var m = c.createObject(null, {host: "127.0.0.1"}); maps.push(m) }
  Component.onCompleted: { load("file://$T/etc/dashv/9/ClusterMap.qml"); load("file://$T/etc/dashv/10/ClusterMap.qml") }
  Timer { interval: 4000; running: true; onTriggered: {
    for (var i = 0; i < maps.length; i++) { var v = maps[i].children[maps[i].children.length - 1]
      console.log("map", i, "source", v.source, "status", v.status, "streaming", maps[i].streaming) }
    Qt.quit() } }
}
Q
cd /tmp
python3 /Users/tritty/Documents/code/JLY/cluster_video/test/fake_stream.py $HOME/cvtest/test.h264 > /dev/null 2>&1 & SRV=$!
sleep 1
QT_QUICK_BACKEND=software QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH=$T/sys timeout 20 /usr/lib/x86_64-linux-gnu/qt5/bin/qmlscene $T/main.qml 2>&1 | grep -v "^$" | tail -12
kill $SRV 2>/dev/null || true
