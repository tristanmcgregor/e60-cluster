// Speed-limit sign for the speedometer: white disc, red ring, the limit in black. Over the
// limit (plus the margin from the phone settings) it fills red with a white number.
// In a school zone (in force) it sits on a yellow plate marked SCHOOL, like the roadside sign.
import QtQuick 2.14
import "."

Rectangle {
    id: sign

    property int limit: 0          // in the display unit; 0 hides the sign
    property bool over: false
    property bool school: false

    width: 56; height: 56; radius: width / 2
    visible: opacity > 0.01
    opacity: limit > 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 250 } }
    color: over ? "#e0251b" : "#ffffff"
    border.color: "#e0251b"
    border.width: 6
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {                    // school-zone plate behind the disc
        z: -1
        anchors.horizontalCenter: parent.horizontalCenter
        y: -6
        width: parent.width + 12; height: parent.height + 26
        radius: 8
        color: "#ffd200"
        visible: sign.school
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            text: "SCHOOL"
            color: "#111111"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            font.family: Theme.font
        }
    }

    Text {
        anchors.centerIn: parent
        text: sign.limit
        color: sign.over ? "#ffffff" : "#111111"
        font.pixelSize: sign.limit >= 100 ? 20 : 24
        font.bold: true
        font.family: Theme.font
    }
}
