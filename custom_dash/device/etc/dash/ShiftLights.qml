// Shift lights for the sport layout: a row of segments along the top hairline that fill
// green, amber, then red as revs approach the shift point, and all flash red at it.
// The shift point is the warm-up redline less a margin, so it rises as the oil warms.
import QtQuick 2.14
import "."

Item {
    id: lights

    property int rpm: 0
    property int shiftRpm: 6800
    property int window: 2000
    property int count: 15

    readonly property int startRpm: shiftRpm - window
    readonly property real level: Math.max(0, Math.min(1, (rpm - startRpm) / Math.max(1, window)))
    readonly property bool atShift: rpm >= shiftRpm
    property bool flashOn: true

    height: 10

    Timer {
        interval: 62                  // 8 Hz flash
        running: lights.atShift && lights.visible
        repeat: true
        onTriggered: lights.flashOn = !lights.flashOn
        onRunningChanged: lights.flashOn = true
    }

    Row {
        anchors.fill: parent
        spacing: 6
        Repeater {
            model: lights.count
            Rectangle {
                readonly property real at: (index + 1) / lights.count
                readonly property bool lit: lights.atShift || lights.level >= at - 0.5 / lights.count
                width: (lights.width - (lights.count - 1) * 6) / lights.count
                height: lights.height
                radius: 2
                color: lights.atShift ? "#ff2a20"
                     : at <= 0.6 ? "#35d07f"
                     : at <= 0.85 ? "#ffb340" : "#ff3b30"
                opacity: !lit ? 0.12 : (lights.atShift && !lights.flashOn ? 0.15 : 1)
            }
        }
    }
}
