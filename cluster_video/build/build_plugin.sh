#!/bin/sh
# Host side: runs container_build.sh in an arm64 debian:stretch container inside the
# Lima VM "kbuild". Output: cluster_video/out/qml/ClusterVideo/
#   ~/tools/lima/bin/limactl shell kbuild sh /Users/tritty/Documents/code/JLY/cluster_video/build/build_plugin.sh
set -eu
CV=/Users/tritty/Documents/code/JLY/cluster_video
mkdir -p "$HOME/cvwork"
nerdctl run --rm --platform linux/arm64 \
	-v "$CV:/src" -v "$HOME/cvwork:/work" \
	debian:stretch sh /src/build/container_build.sh
