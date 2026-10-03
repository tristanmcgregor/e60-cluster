// Default centre-panel content: range, trip computer, trip counters.
import QtQuick 2.14
import "."
import "Units.js" as Units

Item {
    id: card

    property var car

    width: 440
    height: 430

    readonly property bool mph: car.useMph

    function orDash(s) { return s && s !== "" ? s : "--" }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14

        // range, the number people look for first
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RANGE"
                color: Theme.textDim
                font.pixelSize: Theme.tLabel
                font.family: Theme.font
                font.letterSpacing: 2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Units.withUnit(card.mph ? card.car.rangeMiles : card.car.range, card.mph)
                color: Theme.text
                font.pixelSize: Theme.tLarge + 2
                font.family: Theme.font
            }
        }

        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 400; height: 1; color: Theme.hairline }

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 2
            columnSpacing: 40
            rowSpacing: 10
            Stat { label: "AVG FUEL"; value: card.orDash(card.car.avgFuel) }
            Stat { label: "AVG SPEED"; value: card.orDash(card.car.avgSpeed) }
            Stat { label: "TRIP"; value: card.orDash(card.car.tripDistance) }
            Stat {
                label: "NOW"
                value: card.car.instantFuel !== "" ? card.car.instantFuel + " " + card.car.instantFuelUnit : "--"
            }
        }

        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 400; height: 1; color: Theme.hairline }

        // trip counters and time since the trip computer was reset
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 40
            Stat { width: 120; label: "TRIP A"; value: Units.withUnit(card.mph ? card.car.tripAMiles : card.car.tripA, card.mph) }
            Stat { width: 120; label: "TRIP B"; value: Units.withUnit(card.mph ? card.car.tripBMiles : card.car.tripB, card.mph) }
            Stat { width: 120; label: "DRIVE TIME"; value: card.orDash(card.car.tripTime) }
        }
    }
}
