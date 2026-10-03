#!/bin/bash
# Native (x86, Qt 5.15) functional test of the ClusterVideo plugin source. Run inside the Lima VM.
set -e
CV=/Users/tritty/Documents/code/JLY/cluster_video
B=$HOME/cvtest; rm -rf $B; mkdir -p $B/ClusterVideo
QTI="-I/usr/include/x86_64-linux-gnu/qt5 $(for m in QtCore QtGui QtNetwork QtQml QtQuick; do echo -n "-I/usr/include/x86_64-linux-gnu/qt5/$m "; done)"
moc $QTI $CV/src/clustervideoitem.h -o $B/moc_clustervideoitem.cpp
moc $QTI $CV/src/streamworker.h -o $B/moc_streamworker.cpp
moc $QTI $CV/src/plugin.cpp -o $B/plugin.moc
g++ -std=c++11 -O2 -fPIC -shared -Wall -I$CV/src -I$B $QTI \
  -Wno-deprecated-declarations $CV/src/*.cpp $B/moc_*.cpp -o $B/ClusterVideo/libclustervideo.so \
  -lQt5Quick -lQt5Qml -lQt5Network -lQt5Gui -lQt5Core -lopenh264
cp $CV/qmldir $B/ClusterVideo/
cd $B
ffmpeg -loglevel error -y -f lavfi -i testsrc=size=800x480:rate=30 -t 3 \
  -c:v libx264 -profile:v baseline -pix_fmt yuv420p -bsf:v h264_mp4toannexb -f h264 test.h264
python3 $CV/test/fake_stream.py test.h264 & SRV=$!
sleep 1
QT_SELECT=qt5 QT_QUICK_BACKEND=software QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH=$B timeout 20 /usr/lib/x86_64-linux-gnu/qt5/bin/qmlscene $CV/test/test.qml 2>&1 | grep -vE "^$" | tail -8
kill $SRV 2>/dev/null || true
cp /tmp/cv_test.png $CV/test/cv_test.png && echo "saved $CV/test/cv_test.png"
