// Our own check-control warnings from values the cluster already receives: coolant and oil
// over-temperature, charging faults and a low battery. Each condition must hold for a few
// seconds, is shown once, and re-arms only after the value has recovered past a margin, so
// a reading that hovers at a threshold does not keep popping the message up.
// Battery voltage is EventHub's batteryVoltage in tenths of a volt (142 = 14.2 V); readings
// outside 8–17 V are treated as unknown, so a different scale cannot raise false alarms.
import QtQuick 2.14

QtObject {
    id: warnings

    property var car

    // the latest warning, for the popup
    property string text: ""
    property string icon: ""
    property int seq: 0

    readonly property real volts: car.batteryVoltage >= 80 && car.batteryVoltage <= 170 ? car.batteryVoltage / 10 : 0
    readonly property int coolant: parseInt(car.coolantTemp) || 0
    readonly property bool running: car.rpm > 500

    // [name, active test, recovered test, hold ms, message, icon]
    readonly property var rules: [
        ["coolant", function() { return coolant >= 115 }, function() { return coolant < 110 }, 3000,
         function() { return "Coolant temperature high  ·  " + coolant + "°C" }, "icons/coolant_warn.png"],
        ["oil", function() { return car.oilTempInt >= 140 }, function() { return car.oilTempInt < 135 }, 3000,
         function() { return "Engine oil temperature high  ·  " + car.oilTempInt + "°C" }, "icons/oil_warn.png"],
        ["charge_low", function() { return running && volts > 0 && volts < 12.6 }, function() { return volts >= 13.0 }, 10000,
         function() { return "Charging fault  ·  " + volts.toFixed(1) + " V" }, "icons/battery_warn.png"],
        ["charge_high", function() { return running && volts > 15.2 }, function() { return volts <= 14.8 }, 5000,
         function() { return "Charging voltage high  ·  " + volts.toFixed(1) + " V" }, "icons/battery_warn.png"],
        ["battery_low", function() { return !running && car.ignitionOn && volts > 0 && volts < 11.8 }, function() { return volts >= 12.2 }, 10000,
         function() { return "Battery low  ·  " + volts.toFixed(1) + " V" }, "icons/battery_warn.png"]
    ]
    property var since: ({})      // name -> time the condition started
    property var shown: ({})      // name -> true until recovered

    function check() {
        var now = Date.now()
        for (var i = 0; i < rules.length; i++) {
            var r = rules[i], name = r[0]
            if (shown[name]) {
                if (r[2]()) shown[name] = false
                continue
            }
            if (!r[1]()) { since[name] = 0; continue }
            if (!since[name]) since[name] = now
            if (now - since[name] >= r[3]) {
                shown[name] = true
                text = r[4]()
                icon = r[5]
                seq++
                console.log("[dash] warning " + name + ": " + text)
            }
        }
    }

    property Timer ticker: Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: warnings.check()
    }
}
