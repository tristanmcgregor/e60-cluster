// Bottom tab between the odometer and range: the Android Auto track, or the caller during a call.
// With album art (ClusterLink "media" message field "art") it grows into a small now-playing card.
import QtQuick 2.14
import "."

Item {
    id: tab

    property var nav

    readonly property bool calling: nav.callActive
    readonly property bool hasMedia: nav.mediaTitle !== ""
    readonly property bool showArt: !calling && hasMedia && nav.mediaArt !== ""

    width: showArt ? 420 : 400          // fits between the odometer and the range
    height: showArt ? 62 : 44
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
        radius: tab.showArt ? 14 : height / 2
        color: tab.calling ? "#14281b" : "#14171b"
        border.color: tab.calling ? "#2f7a4c" : Theme.hairline
        border.width: 1
    }
    // now-playing card: cover, title, artist
    Row {
        visible: tab.showArt
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        spacing: 14
        Rectangle {               // rounded cover
            width: 48; height: 48; radius: 7
            color: "#000000"
            clip: true
            Image {
                anchors.fill: parent
                source: tab.showArt ? nav.mediaArt : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: tab.width - 8 - 48 - 14 - 20
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: nav.mediaTitle
                color: nav.mediaPlaying ? Theme.text : Theme.textDim
                font.pixelSize: 22
                font.family: Theme.font
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: nav.mediaArtist
                color: Theme.textDim
                font.pixelSize: 17
                font.family: Theme.font
            }
        }
    }
    Row {
        visible: !tab.showArt
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
