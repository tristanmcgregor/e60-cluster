// Notices when /etc/init.d/S61dashupdate installs a newer release during this drive, so
// the dash can say it loads at the next start-up. Only a change to /etc/dash_active seen
// while running counts: if a release is already staged at start-up but this dash is an
// older one, d.qml fell back from it, and "loads next start" would not be true.
import QtQuick 2.14

Item {
    id: watch

    // the desktop preview points these at a temp file and a quicker poll
    property string activeFile: typeof dashActiveFile !== "undefined" ? dashActiveFile : "file:///etc/dash_active"
    property int pollMs: typeof dashActiveFile !== "undefined" ? 500 : 30000
    property int running: 0          // release of the loaded dash (InfoPage reads its RELEASE)
    property int pending: 0          // newer release installed this drive, 0 = none
    property int seq: 0              // bumped once per newly installed release, for the popup

    property int startActive: -1     // dash_active when first read

    function read() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            var a = parseInt((xhr.responseText || "").trim()) || 0
            if (watch.startActive < 0) { watch.startActive = a; return }
            if (a !== watch.startActive && a > watch.running && a !== watch.pending) {
                console.log("[dash] release " + a + " installed, loads at next start-up")
                watch.pending = a
                watch.seq++
            }
        }
        xhr.open("GET", activeFile)
        xhr.send()
    }

    Component.onCompleted: {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            watch.running = parseInt((xhr.responseText || "").trim()) || 0
            watch.read()
        }
        xhr.open("GET", Qt.resolvedUrl("RELEASE"))
        xhr.send()
    }

    // the updater checks once a minute, so this does not need to be quicker
    Timer { interval: watch.pollMs; repeat: true; running: true; onTriggered: watch.read() }
}
