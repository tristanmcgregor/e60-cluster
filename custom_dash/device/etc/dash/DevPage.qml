// Hidden centre page (hold BC on INFO): raw EventHub values, refreshed twice a second.
// For finding out what this car's MCU actually reports (gear strings in S/M, oil temperature).
import QtQuick 2.14
import "."

Item {
    id: page

    property var car
    property var gps          // GpsCheck
    readonly property var names: [
        "rpm", "speed", "gear", "gearAuto", "gearManual", "gearShow",
        "oilTempInt", "oilTemp", "waterTemperature", "waterTemperatureRaw", "gearBoxTempInt",
        "batteryVoltage", "steeringAngle", "fuel", "acc",
        "lightBrightness", "darkBrightness", "brightMode", "uiStyle", "menuId"
    ]
    // read in the timer, not in bindings: most of these have no NOTIFY signal
    property var values: []
    property string gpsLine: ""

    function gpsText() {
        var g = page.gps, n = g ? g.nav : null
        if (!n || n.gpsKph < 0 || Date.now() - n.gpsAt > 3000) return "No GPS speed from the head unit"
        var raw = g.rawKph()
        return "GPS " + n.gpsKph.toFixed(1) + " km/h (\u00b1" + n.gpsAcc + " m)   \u00b7   MCU " + raw +
               "   \u00b7   dash " + page.car.speed
    }
    function pct(v) { return (v >= 0 ? "+" : "") + v.toFixed(1) + " %" }

    width: 480
    height: 400

    Timer {
        interval: 500; running: page.visible; repeat: true; triggeredOnStart: true
        onTriggered: {
            var hub = page.car.eventHub, out = []
            for (var i = 0; i < page.names.length; i++) {
                var v = hub ? hub[page.names[i]] : undefined
                out.push(v === undefined ? "n/a" : String(v))
            }
            page.values = out
            page.gpsLine = page.gpsText()
        }
    }

    Grid {
        id: grid
        columns: 2
        columnSpacing: 24
        rowSpacing: 3
        Repeater {
            model: page.names
            Row {
                spacing: 8
                width: 228
                Text {
                    width: 132
                    text: modelData
                    color: Theme.textDim
                    font.pixelSize: 15
                    font.family: Theme.font
                    elide: Text.ElideRight
                }
                Text {
                    width: 88
                    text: page.values[index] || ""
                    color: Theme.text
                    font.pixelSize: 15
                    font.family: Theme.font
                    elide: Text.ElideRight
                }
            }
        }
    }

    // GPS speed check (GpsCheck): what the speed correction should be
    Column {
        anchors.top: grid.bottom
        anchors.topMargin: 18
        spacing: 4
        Text {
            text: "GPS SPEED CHECK"
            color: Theme.textDim
            font.pixelSize: 15
            font.letterSpacing: 1.5
            font.family: Theme.font
        }
        Text {
            text: page.gpsLine
            color: Theme.text
            font.pixelSize: 17
            font.family: Theme.font
        }
        Text {
            text: !page.gps ? "" : isNaN(page.gps.measured)
                  ? "Learning: drive steadily above 40 km/h (" + page.gps.samples + "/" + page.gps.minSamples + " s)"
                  : "Measured " + page.pct(page.gps.measured) + " over " + page.gps.samples + " s"
            color: Theme.text
            font.pixelSize: 17
            font.family: Theme.font
        }
        Text {
            text: !page.car ? "" : "In use: " + page.pct((page.car.speedFactor - 1) * 100) +
                  (page.car.usingLearned ? " (learned from GPS)" : page.car.speedAuto ? " (manual, until learned)" : " (manual)")
            color: Theme.text
            font.pixelSize: 17
            font.family: Theme.font
        }
    }
}
