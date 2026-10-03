// Centre panel of the sport layout: digital revs, the live shift point, and oil and
// coolant temperature bars (the shift point follows oil temperature while warming up).
import QtQuick 2.14
import "."

Item {
    id: card

    property var car

    width: 520
    height: 470

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 34
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "DYNAMIC"
            color: Theme.sportAccent
            font.pixelSize: Theme.tLabel + 3
            font.family: Theme.font
            font.letterSpacing: 4
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.car.rpm
            color: card.car.rpm >= card.car.shiftRpm ? Theme.sportAccent : Theme.text
            font.pixelSize: 112
            font.family: Theme.font
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "rpm   ·   shift " + card.car.shiftRpm
            color: Theme.textDim
            font.pixelSize: Theme.tBody
            font.family: Theme.font
        }
        Item { width: 1; height: 26 }

        Repeater {
            model: [
                { label: "OIL", temp: card.car.oilTempInt, cold: 40, hot: 130 },
                { label: "COOLANT", temp: parseInt(card.car.coolantTemp) || 0, cold: 40, hot: 120 }
            ]
            Row {
                spacing: 16
                Text {
                    width: 110
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: Theme.textDim
                    font.pixelSize: Theme.tLabel
                    font.family: Theme.font
                    font.letterSpacing: 1.5
                }
                Rectangle {           // bar track, filling from cold to hot
                    width: 230; height: 8; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.track
                    Rectangle {
                        readonly property real f: Math.max(0, Math.min(1,
                            (modelData.temp - modelData.cold) / (modelData.hot - modelData.cold)))
                        width: parent.width * f; height: parent.height; radius: 4
                        color: modelData.temp <= 0 ? "transparent"
                             : modelData.temp < 70 ? "#8a7cff"
                             : modelData.temp >= modelData.hot - 10 ? Theme.critical : Theme.text
                    }
                }
                Text {
                    width: 90
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: modelData.temp > 0 ? modelData.temp + "°C" : "--"
                    color: Theme.text
                    font.pixelSize: Theme.tBody
                    font.family: Theme.font
                }
            }
        }
    }
}
