// Label-over-value pair used by the trip computer.
import QtQuick 2.14
import "."

Column {
    property string label: ""
    property string value: ""
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
        text: parent.value
        color: Theme.text
        font.pixelSize: Theme.tMedium
        font.family: Theme.font
    }
}
