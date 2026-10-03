// Speed-limit sign for the speedometer: white disc, red ring, the limit in black. Over the
// limit (plus the margin from the phone settings) it fills red with a white number.
import QtQuick 2.14
import "."

Rectangle {
    id: sign

    property int limit: 0          // in the display unit; 0 hides the sign
    property bool over: false

    width: 56; height: 56; radius: width / 2
    visible: opacity > 0.01
    opacity: limit > 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 250 } }
    color: over ? "#e0251b" : "#ffffff"
    border.color: "#e0251b"
    border.width: 6
    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: sign.limit
        color: sign.over ? "#ffffff" : "#111111"
        font.pixelSize: sign.limit >= 100 ? 20 : 24
        font.bold: true
        font.family: Theme.font
    }
}
