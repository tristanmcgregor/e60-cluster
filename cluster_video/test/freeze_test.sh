#!/bin/bash
# S61dashupdate freeze watchdog: a dash whose heartbeat stops is logged, killed and started again;
# a live heartbeat or no heartbeat file is left alone.
S61=/Users/tritty/Documents/code/JLY/custom_dash/device/etc/init.d/S61dashupdate
T=/tmp/freezetest; rm -rf $T; mkdir -p $T/bin $T/etc
cp /bin/sleep $T/bin/Launcher
printf '#!/bin/sh\nwhile true; do sleep 1; done\n' > $T/bin/process.sh
chmod +x $T/bin/*
cd $T/bin
./process.sh & PS=$!
export DASH_TMP=$T DASH_ETC=$T/etc DASH_FREEZE_CHECKS=3
./Launcher 1000 & L1=$!
sh $S61 guard & GUARD=$!
sleep 3
# heartbeat like the plugin: counter every 2 s
( n=0; while true; do n=$((n+1)); echo $n > $T/dash_alive; sleep 2; done ) & BEAT=$!
sleep 14
echo "case 1: live heartbeat -> same Launcher (want $L1): $(pgrep -x Launcher)"
kill $BEAT
sleep 16
echo "case 2: heartbeat stopped -> old one killed: $(kill -0 $L1 2>/dev/null && echo alive || echo killed), running now: $(pgrep -x Launcher | wc -l) (want 1)"
L2=$(pgrep -x Launcher)
grep -q "dash frozen" $T/etc/dashfreeze.log && echo "   freeze log written: $(head -1 $T/etc/dashfreeze.log)"
grep -E "VmRSS|state=" $T/etc/dashfreeze.log | head -3
sleep 14
echo "case 3: new dash, no heartbeat file -> left alone (want $L2): $(pgrep -x Launcher)"
echo "case 4: dash crashes (heartbeat file left behind) -> started again"
echo 1 > $T/dash_alive; sleep 3; kill -9 $L2; sleep 14
echo "   old killed: $(kill -0 $L2 2>/dev/null && echo alive || echo gone), running: $(pgrep -x Launcher | wc -l) (want 1)"
L3=$(pgrep -x Launcher)
echo "case 5: dash quits cleanly (no heartbeat file) -> not restarted"
rm -f $T/dash_alive; kill $L3; sleep 14
echo "   running: $(pgrep -x Launcher | wc -l) (want 0)"
cat $T/dashupdate.log
kill $GUARD $PS; pkill -x Launcher
