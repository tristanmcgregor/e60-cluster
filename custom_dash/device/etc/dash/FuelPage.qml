// Centre page: everything about fuel. Level and range, consumption now and over the last
// 30 minutes, this tank since the last refuel, fuel to the destination, and the refuel log.
import QtQuick 2.14
import "."

Column {
    id: page

    property var car
    property var fuel                      // FuelTracker

    width: 480
    spacing: 10

    function n1(x) { return x > 0 ? x.toFixed(1) : "--" }
    function money(x) { return "$" + x.toFixed(2) }

    Row {
        spacing: 0
        Stat { valueSize: 26; width: 160; label: "FUEL"; value: page.car.fuelPercent + "%  ·  " + Math.round(page.fuel.fuelLitres) + " L" }
        Stat { valueSize: 26; width: 140; label: "RANGE"; value: page.fuel.rangeKm > 0 ? Math.round(page.fuel.rangeKm) + " km" : "--" }
        Stat { valueSize: 26; width: 180; label: "NOW"; value: page.car.instantFuel !== "" ? page.car.instantFuel + " " + page.car.instantFuelUnit : "--" }
    }

    // last 30 minutes, one bar per minute
    Item {
        width: page.width; height: 92
        readonly property var bars: page.fuel.history
        readonly property real peak: Math.max(15, Math.max.apply(null, bars.concat([0])))
        Text {
            text: "LAST 30 MIN"
            color: Theme.textDim; font.pixelSize: Theme.tLabel; font.family: Theme.font; font.letterSpacing: 1.5
        }
        Text {
            anchors.right: parent.right
            readonly property var moving: parent.bars.filter(function(b) { return b > 0 })
            text: moving.length ? "avg " + (moving.reduce(function(a, b) { return a + b }, 0) / moving.length).toFixed(1) + " L/100km" : ""
            color: Theme.textDim; font.pixelSize: Theme.tLabel; font.family: Theme.font
        }
        Row {
            anchors.bottom: parent.bottom
            spacing: 4
            Repeater {
                model: 30
                Rectangle {
                    readonly property real v: { var b = parent.parent.bars, i = index - (30 - b.length); return i >= 0 ? b[i] : 0 }
                    width: (page.width - 29 * 4) / 30
                    height: Math.max(2, 64 * v / parent.parent.peak)
                    anchors.bottom: parent.bottom
                    radius: 2
                    color: v <= 0 ? Theme.track : v > 14 ? Theme.warn : Theme.text
                    opacity: v <= 0 ? 0.6 : 0.85
                }
            }
        }
    }

    Rectangle { width: page.width; height: 1; color: Theme.hairline }

    Row {
        spacing: 0
        Stat { valueSize: 26; width: 160; label: "THIS TANK"; value: Math.round(page.fuel.tankKm) + " km" }
        Stat { valueSize: 26; width: 140; label: "AVERAGE"; value: page.n1(page.fuel.tankAvg) + " L/100" }
        Stat { valueSize: 26; width: 180; label: "USED · COST"; value: page.fuel.tankLitres.toFixed(1) + " L · " + page.money(page.fuel.tankCost) }
    }

    // fuel to destination (only with a route)
    Text {
        visible: page.fuel.destStatus !== "none"
        width: page.width
        elide: Text.ElideRight
        text: "TO DESTINATION  " + Math.round(page.fuel.destKm) + " km  ·  " +
              (page.fuel.arriveWithKm >= 0 ? "arrive with " + Math.round(page.fuel.arriveWithKm) + " km range"
                                            : "short by " + Math.round(-page.fuel.arriveWithKm) + " km, refuel on the way")
        color: page.fuel.destStatus === "short" ? Theme.critical : page.fuel.destStatus === "tight" ? Theme.warn : Theme.ok
        font.pixelSize: Theme.tBody - 2
        font.family: Theme.font
    }

    // refuel log: the last two tanks
    Column {
        spacing: 2
        Text {
            text: page.fuel.log.length ? "PREVIOUS TANKS" : "PREVIOUS TANKS  ·  none logged yet"
            color: Theme.textDim; font.pixelSize: Theme.tLabel; font.family: Theme.font; font.letterSpacing: 1.5
        }
        Repeater {
            model: page.fuel.log.slice(0, 2)
            Text {
                text: modelData.date + "   " + modelData.km + " km   " + page.n1(modelData.avg) + " L/100   " +
                      modelData.litres.toFixed(1) + " L   " + page.money(modelData.cost)
                color: Theme.text; font.pixelSize: Theme.tBody - 4; font.family: Theme.font
            }
        }
    }
}
