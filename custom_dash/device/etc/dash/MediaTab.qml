// Bottom tab between the odometer and range: the Android Auto track, or the caller during a call.
import QtQuick 2.14
import "."

Item {
    id: tab

    property var nav

    readonly property bool calling: nav.callActive
    readonly property bool hasMedia: nav.mediaTitle !== ""

    width: 400
    height: 44
    opacity: (calling || hasMedia) ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 250 } }

    function callText() {
        var who = nav.callerName !== "" ? nav.callerName : (nav.callerNumber !== "" ? nav.callerNumber : "Unknown caller")
        if (nav.callState === 4) return who + "  ·  Incoming call"
        if (nav.callState === 2) return who + "  ·  On hold"
        var m = Math.floor(nav.callSeconds / 60), sec = nav.callSeconds % 60
        return who + "  ·  " + m + ":" + (sec < 10 ? "0" : "") + sec
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: tab.calling ? "#14281b" : "#14171b"
        border.color: tab.calling ? "#2f7a4c" : Theme.hairline
        border.width: 1
    }
    Row {
        anchors.centerIn: parent
        spacing: 12
        width: Math.min(implicitWidth, tab.width - 36)
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26; smooth: true
            source: tab.calling ? "icons/call_in.png" : "icons/media_note.png"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, tab.width - 36 - 26 - 12)
            elide: Text.ElideRight
            text: tab.calling ? tab.callText()
                              : nav.mediaTitle + (nav.mediaArtist !== "" ? "  ·  " + nav.mediaArtist : "")
            color: tab.calling ? "#c8f5d8" : (nav.mediaPlaying ? Theme.text : Theme.textDim)
            font.pixelSize: 22
            font.family: Theme.font
        }
    }
}
