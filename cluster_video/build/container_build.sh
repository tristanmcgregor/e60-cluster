#!/bin/sh
# Builds the ClusterVideo QML plugin for the JLY cluster.
# Runs INSIDE an arm64 debian:stretch container (glibc 2.24 / GCC 6, both older
# than the cluster's glibc 2.25 / libstdc++ 6.0.24), launched by build_plugin.sh.
#
#   /src   = cluster_video/ (this repo dir, read-write)
#   /work  = persistent scratch volume (Qt sources, openh264) so reruns are fast
set -eu

QT_VER=5.14.2
H264_VER=2.1.1
OUT=/src/out
SYSROOT=/src/sysroot/usr/local/Qt_5.14.2/lib
mkdir -p /work "$OUT"
cd /work

if ! command -v make > /dev/null || ! command -v g++ > /dev/null; then
	printf '%s\n' "deb http://archive.debian.org/debian stretch main" \
		"deb http://archive.debian.org/debian-security stretch/updates main" > /etc/apt/sources.list
	apt-get -o Acquire::Check-Valid-Until=false update -qq
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --allow-unauthenticated \
		build-essential perl python wget xz-utils ca-certificates \
		libgles2-mesa-dev libegl1-mesa-dev pkg-config > /dev/null
fi

# ---- Qt 5.14.2 headers + moc (configure only; libraries come from the cluster) ----
if [ ! -x /work/qtbase/bin/moc ]; then
	[ -d qtbase ] || {
		wget -q https://download.qt.io/archive/qt/5.14/$QT_VER/submodules/qtbase-everywhere-src-$QT_VER.tar.xz
		tar xf qtbase-everywhere-src-$QT_VER.tar.xz && mv qtbase-everywhere-src-$QT_VER qtbase
	}
	cd qtbase
	[ -f Makefile ] || ./configure -opensource -confirm-license -release -prefix /opt/qt \
		-opengl es2 -no-xcb -no-feature-vulkan -nomake examples -nomake tests \
		-qt-zlib -qt-pcre -no-icu -no-dbus > /work/qt-configure.log 2>&1
	# configure leaves only the top Makefile; generate src/ and build just bootstrap + moc
	[ -f src/Makefile ] || make sub-src-qmake_all > /work/qt-qmake-all.log 2>&1
	T=$(grep -oE '^(sub-moc|sub-tools-moc):' src/Makefile | head -1 | tr -d :)
	(cd src && make -j4 "${T:-sub-moc}" > /work/qt-moc.log 2>&1)
	cd /work
fi
MOC=/work/qtbase/bin/moc

if [ ! -d /work/qtdeclarative/include/QtQuick ]; then
	[ -d qtdeclarative ] || {
		wget -q https://download.qt.io/archive/qt/5.14/$QT_VER/submodules/qtdeclarative-everywhere-src-$QT_VER.tar.xz
		tar xf qtdeclarative-everywhere-src-$QT_VER.tar.xz && mv qtdeclarative-everywhere-src-$QT_VER qtdeclarative
	}
	cd qtdeclarative
	perl /work/qtbase/bin/syncqt.pl -version $QT_VER -outdir /work/qtdeclarative /work/qtdeclarative > /work/syncqt-decl.log 2>&1
	# qmake would normally generate these from configure.json; every feature is on by
	# default in 5.14 except the Direct3D backend, which has no meaning on Linux.
	for mod in qml:QtQml quick:QtQuick qmlmodels:QtQmlModels; do
		dir=${mod%%:*}; inc=${mod##*:}
		lower=$(echo $inc | tr A-Z a-z)
		cfg=include/$inc/${lower}-config.h
		: > $cfg
		[ -f src/$dir/configure.json ] && \
			grep -oE '^\s*"[a-z0-9_-]+": \{' src/$dir/configure.json | \
			grep -oE '[a-z0-9_-]+' | while read f; do
				m=$(echo $f | tr - _)
				case $m in d3d12|quick_designer) v=-1 ;; *) v=1 ;; esac
				echo "#define QT_FEATURE_$m $v" >> $cfg
			done
		touch include/$inc/${lower}-config_p.h
	done
	cd /work
fi

# ---- OpenH264 (BSD-2), shipped next to the plugin ----
if [ ! -f /work/openh264/libopenh264.so ]; then
	[ -d openh264 ] || {
		wget -q -O openh264.tar.gz https://github.com/cisco/openh264/archive/refs/tags/v$H264_VER.tar.gz
		tar xf openh264.tar.gz && mv openh264-$H264_VER openh264
	}
	(cd openh264 && make -j4 OS=linux ARCH=arm64 libopenh264.so > /work/openh264.log 2>&1)
fi

# ---- the plugin ----
QTI="-I/work/qtbase/include -I/work/qtbase/include/QtCore -I/work/qtbase/include/QtGui \
     -I/work/qtbase/include/QtNetwork -I/work/qtdeclarative/include \
     -I/work/qtdeclarative/include/QtQml -I/work/qtdeclarative/include/QtQuick \
     -I/work/qtdeclarative/include/QtQmlModels -I/work/qtbase/mkspecs/linux-g++"
B=/work/plugin
rm -rf $B && mkdir -p $B/inc/wels
# packaged OpenH264 installs its API as <wels/...>; the source tree keeps it in codec/api/svc
cp /work/openh264/codec/api/svc/*.h $B/inc/wels/
$MOC $QTI /src/src/clustervideoitem.h -o $B/moc_clustervideoitem.cpp
$MOC $QTI /src/src/streamworker.h -o $B/moc_streamworker.cpp
$MOC $QTI /src/src/plugin.cpp -o $B/plugin.moc
CXXFLAGS="-std=c++11 -O2 -fPIC -Wall -DQT_NO_DEBUG -DQT_PLUGIN -DQT_QUICK_LIB -DQT_QML_LIB \
          -DQT_NETWORK_LIB -DQT_GUI_LIB -DQT_CORE_LIB -I/src/src -I$B -I$B/inc $QTI"
for f in /src/src/clustervideoitem.cpp /src/src/streamworker.cpp /src/src/plugin.cpp \
         $B/moc_clustervideoitem.cpp $B/moc_streamworker.cpp; do
	g++ $CXXFLAGS -c "$f" -o $B/$(basename "$f" .cpp).o
done
g++ -shared -o $B/libclustervideo.so $B/*.o \
	-Wl,-rpath,'$ORIGIN' -Wl,--allow-shlib-undefined \
	-L$SYSROOT -lQt5Quick -lQt5Qml -lQt5Network -lQt5Gui -lQt5Core \
	-L/work/openh264 -lopenh264 -lpthread

# ---- stage the QML module ----
M=$OUT/qml/ClusterVideo
rm -rf $M && mkdir -p $M
cp $B/libclustervideo.so /src/qmldir $M/
cp -L /work/openh264/libopenh264.so.6 $M/ 2>/dev/null || cp -L /work/openh264/libopenh264.so $M/libopenh264.so.6
strip --strip-unneeded $M/*.so*
echo "== built"
ls -la $M
echo "== highest symbol versions required"
objdump -T $M/libclustervideo.so $M/libopenh264.so.6 | grep -oE 'GLIBC_[0-9.]+|GLIBCXX_[0-9.]+|CXXABI_[0-9.]+' | sort -uV | tail -6
readelf -d $M/libclustervideo.so | grep -E 'NEEDED|RUNPATH|RPATH'
