// Label-over-value pair used by the trip computer.
import QtQuick 2.14
import "."

Column {
    property string label: ""
    property string value: ""
    property bool fit: false
    property int valueSize: Theme.tMedium
    spacing: 0
    width: 200
    Text {
        text: parent.label
        color: Theme.textDim
        font.pixelSize: Theme.tLabel
        font.family: Theme.font
        font.letterSpacing: 1.5
    }
    Text {
        // fit: long values end in "…" at the Stat's width instead of running off (INFO page)
        width: parent.fit ? parent.width : implicitWidth
        elide: parent.fit ? Text.ElideRight : Text.ElideNone
        text: parent.value
        color: Theme.text
        font.pixelSize: parent.valueSize
        font.family: Theme.font
    }
}
