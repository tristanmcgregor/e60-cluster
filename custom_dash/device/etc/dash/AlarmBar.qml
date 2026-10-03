// Row of active warning lights, using the stock Launcher's own icon art (qrc:/images/alarm/*).
import QtQuick 2.14
import "Alarms.js" as Alarms

Row {
    id: bar

    property var ids: []
    property var states: []
    property string iconBase: "qrc:/"
    property int iconSize: 52
    property int maxIcons: 7

    spacing: 10

    // shared blink clocks so every flashing icon is in phase
    property bool fastOn: true
    property bool slowOn: true
    Timer { interval: 250; running: bar.ids.length > 0; repeat: true; onTriggered: bar.fastOn = !bar.fastOn }
    Timer { interval: 600; running: bar.ids.length > 0; repeat: true; onTriggered: bar.slowOn = !bar.slowOn }

    Repeater {
        // critical lights first, then the rest, capped to the space available
        model: {
            var crit = [], rest = []
            for (var i = 0; i < bar.ids.length; i++)
                (Alarms.critical(bar.ids[i]) ? crit : rest).push(bar.ids[i])
            return crit.concat(rest).slice(0, bar.maxIcons)
        }
        Image {
            readonly property int st: bar.states[modelData] || 0
            width: bar.iconSize
            height: bar.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: bar.iconBase + Alarms.icon(modelData)
            opacity: st === 2 ? (bar.fastOn ? 1 : 0.15) : st === 3 ? (bar.slowOn ? 1 : 0.15) : 1
            onStatusChanged: if (status === Image.Error) source = bar.iconBase + "images/alarm/ico_jinggao.png"
        }
    }
}
