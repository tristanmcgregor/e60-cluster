#!/bin/bash
set -e
T=/tmp/imptest; rm -rf $T; mkdir -p $T/r1 $T/r2 $T/sys
cp -r $HOME/cvtest/ClusterVideo $T/r1/ClusterVideo
cp -r $HOME/cvtest/ClusterVideo $T/r2/ClusterVideo
for r in r1 r2; do printf "plugin clustervideo\n" > $T/$r/ClusterVideo/qmldir; done
cp -r $HOME/cvtest/ClusterVideo $T/sys/ClusterVideo
for r in r1 r2; do cat > $T/$r/Local.qml <<Q
import QtQuick 2.14
import "ClusterVideo" 1.0
ClusterVideoItem { port: 1 }
Q
done
cat > $T/r2/System.qml <<Q
import QtQuick 2.14
import ClusterVideo 1.0
ClusterVideoItem { port: 1 }
Q
cat > $T/main.qml <<Q
import QtQuick 2.14
Item {
  function tryLoad(u) { var c = Qt.createComponent(u); console.log(u, c.status === Component.Ready ? "READY" : c.errorString()); if (c.status === Component.Ready) { var o = c.createObject(null); console.log(" created", o !== null); if (o) o.destroy() } }
  Component.onCompleted: { tryLoad("file://$T/r1/Local.qml"); tryLoad("file://$T/r2/Local.qml"); tryLoad("file://$T/r2/System.qml"); Qt.quit() }
}
Q
cd $T
QML_IMPORT_TRACE=1 QT_QUICK_BACKEND=software QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH=$T/sys timeout 15 /usr/lib/x86_64-linux-gnu/qt5/bin/qmlscene main.qml 2>&1 | tail -20
