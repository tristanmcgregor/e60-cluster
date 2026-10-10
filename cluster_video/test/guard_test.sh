#!/bin/bash
# S61dashupdate launcher_guard: restarts a Launcher that quit after an install, not otherwise.
S61=/Users/tritty/Documents/code/JLY/custom_dash/device/etc/init.d/S61dashupdate
T=/tmp/guardtest; rm -rf $T; mkdir -p $T/bin
cp /bin/sleep $T/bin/Launcher     # a real binary, so the process is named Launcher
printf '#!/bin/sh\nwhile true; do sleep 1; done\n' > $T/bin/process.sh
chmod +x $T/bin/*
cd $T/bin
start_guard() { DASH_TMP=$T sh $S61 guard & GUARD=$!; }
count() { pgrep -x Launcher | wc -l; }
envof() { for p in $(pgrep -x Launcher); do tr '\0' '\n' < /proc/$p/environ | grep ^FOO; tr '\0' ' ' < /proc/$p/cmdline; echo; done; }

$T/bin/process.sh & SUP=$!
FOO=bar $T/bin/Launcher 1000 & 
start_guard; sleep 3
echo "case 1: no install, Launcher quits -> expect no restart"
pkill -x Launcher; sleep 10; echo "   running: $(count) (want 0)"

echo "case 2: install, Launcher quits -> expect restart with same env/args"
FOO=bar $T/bin/Launcher 1000 & sleep 3
date +%s > $T/dash_restart_expected
pkill -x Launcher; sleep 11; echo "   running: $(count) (want 1)"; envof | sed 's/^/   /'
sleep 3; echo "   expect flag cleared: $([ -f $T/dash_restart_expected ] && echo still-there || echo cleared)"

echo "case 3: install, Launcher and process.sh both stopped (JLY update) -> expect no restart"
date +%s > $T/dash_restart_expected
kill $SUP; pkill -x Launcher; sleep 11; echo "   running: $(count) (want 0)"
sed 's/^/   log: /' $T/dashupdate.log
kill $GUARD; pkill -x Launcher; pkill -f guardtest; true
