// Centre menu page: engine and cabin readings, then the service items the car has reported.
import QtQuick 2.14
import "."
import "Units.js" as Units

Item {
    id: page

    property var car

    width: 480
    height: 400

    function orDash(s) { return s && s !== "" ? s : "--" }

    Grid {
        id: readings
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        columns: 3
        columnSpacing: 30
        rowSpacing: 26
        Stat { width: 130; label: "COOLANT"; value: page.orDash(page.car.useMph ? page.car.coolantTempF : page.car.coolantTemp) }
        Stat { width: 130; label: "OIL"; value: page.orDash(page.car.oilTemp) }
        Stat { width: 130; label: "OUTSIDE"; value: page.orDash(page.car.outsideTemp) }
        Stat {
            width: 130
            label: "BATTERY"
            // assumed volts x10 (e.g. 142 = 14.2 V); unconfirmed against the car
            value: page.car.batteryVoltage > 0 ? (page.car.batteryVoltage / 10).toFixed(1) + " V" : "--"
        }
        Stat { width: 130; label: "FUEL"; value: page.car.fuelPercent > 0 ? page.car.fuelPercent + "%" : "--" }
        Stat { width: 130; label: "RANGE"; value: Units.withUnit(page.car.useMph ? page.car.rangeMiles : page.car.range, page.car.useMph) }
    }

    Rectangle {
        id: rule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: readings.bottom; anchors.topMargin: 24
        width: 420; height: 1; color: Theme.hairline
    }

    // service items the MCU has reported (car.service)
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: rule.bottom; anchors.topMargin: 16
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Object.keys(page.car.service).length === 0
            text: "SERVICE  ·  no reminders"
            color: Theme.textDim
            font.pixelSize: Theme.tLabel + 2
            font.family: Theme.font
        }
        Repeater {
            model: {
                var _ = page.car.serviceSeq       // re-evaluate when an item arrives
                var rows = []
                for (var id in page.car.service) {
                    var it = page.car.service[id]
                    var due = it.reminder || it.mileage || it.date || ""
                    rows.push((page.car.serviceNames[id] || ("Item " + id)) + (due !== "" ? "  ·  " + due : ""))
                }
                return rows.slice(0, 3)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SERVICE  " + modelData
                color: Theme.textDim
                font.pixelSize: Theme.tLabel + 2
                font.family: Theme.font
            }
        }
    }
}
