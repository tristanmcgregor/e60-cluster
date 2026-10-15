// Start-up greeting in the centre band: roundel, "Welcome" and a time-of-day line, held for a
// few seconds while the needles sweep, then the centre menu fades back in under it.
import QtQuick 2.14

Item {
    id: card
    property string fontName: Theme.font
    readonly property bool shown: opacity > 0.01
    width: 520; height: 300
    opacity: 0
    visible: shown

    property string greeting: ""

    function show() {
        var h = new Date().getHours()
        greeting = h < 5 ? "Good evening" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        anim.restart()
    }
    function hide() { anim.stop(); fadeOut.restart() }

    // Only on a real start-up, not when an over-the-air dash release reloads a running dash:
    // the cluster has been up for under 3 minutes (/proc/uptime unreadable, as in the desktop
    // preview, counts as start-up).
    function showIfStartup() {
        var xhr = new XMLHttpRequest()
        try {
            xhr.open("GET", "file:///proc/uptime", false)
            xhr.send()
        } catch (e) {}
        var up = parseFloat(xhr.responseText || "")
        if (isNaN(up) || up < 180) show()
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 500; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 3500 }
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InQuad }
    }
    NumberAnimation { id: fadeOut; target: card; property: "opacity"; to: 0; duration: 250 }

    Column {
        anchors.centerIn: parent
        spacing: 18
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "icons/roundel.png"
            width: 130; height: 130; smooth: true; mipmap: true
            scale: 0.92 + 0.08 * card.opacity
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Welcome"
            color: Theme.text
            font.pixelSize: 54; font.family: card.fontName
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.greeting
            color: Theme.textDim
            font.pixelSize: 28; font.family: card.fontName
        }
    }
}
