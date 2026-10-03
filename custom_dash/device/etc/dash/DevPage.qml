// Hidden centre page (hold BC on INFO): raw EventHub values, refreshed twice a second.
// For finding out what this car's MCU actually reports (gear strings in S/M, oil temperature).
import QtQuick 2.14
import "."

Item {
    id: page

    property var car
    readonly property var names: [
        "rpm", "speed", "gear", "gearAuto", "gearManual", "gearShow",
        "oilTempInt", "oilTemp", "waterTemperature", "waterTemperatureRaw", "gearBoxTempInt",
        "batteryVoltage", "steeringAngle", "fuel", "acc",
        "lightBrightness", "darkBrightness", "brightMode", "uiStyle", "menuId"
    ]
    // read in the timer, not in bindings: most of these have no NOTIFY signal
    property var values: []

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
        }
    }

    Grid {
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
}
