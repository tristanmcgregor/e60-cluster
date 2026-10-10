#!/bin/bash
# d.qml: a release installed while running is applied (Qt.quit) once the car has been stopped 5 s,
# not while moving, and not for a release already staged at start-up.
T=/tmp/dqtest; rm -rf $T; mkdir -p $T/etc/dash $T/etc/dashv/9
cp /Users/tritty/Documents/code/JLY/custom_dash/device/etc/d.qml $T/
sed -i "s#property string root: \"/etc\"#property string root: \"$T/etc\"#" $T/d.qml
echo 8 > $T/etc/dash/RELEASE; echo 9 > $T/etc/dash_active
for d in dash dashv/9; do cat > $T/etc/$d/Dashboard.qml <<Q
import QtQuick 2.14
import QtQuick.Window 2.14
Window {
    visible: false
    property QtObject car: QtObject {
        property int speed: 0
    }
}
Q
done
run() { # $1 speed, $2 seconds before install (-1 = none)
  sed -i "s/property int speed: .*/property int speed: $1/" $T/etc/dash/Dashboard.qml $T/etc/dashv/9/Dashboard.qml
  echo 9 > $T/etc/dash_active
  ( [ "$2" -ge 0 ] && sleep $2 && mkdir -p $T/etc/dashv/10 && echo 10 > $T/etc/dash_active ) &
  start=$(date +%s)
  QT_QPA_PLATFORM=offscreen timeout 14 /usr/lib/x86_64-linux-gnu/qt5/bin/qmlscene $T/d.qml 2>&1 | grep "d.qml" | sed 's/^/   /'
  echo "   exit after $(( $(date +%s) - start )) s"
}
echo "stopped, install at 2 s (expect quit ~8 s):"; run 0 2
echo "moving, install at 2 s (expect no quit, 14 s timeout):"; run 50 2
echo "stopped, nothing installed (expect 14 s timeout):"; run 0 -1
