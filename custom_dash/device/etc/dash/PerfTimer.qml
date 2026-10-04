// Performance timer: 0–100 km/h from a standstill and 80–120 km/h rolling, from the
// cluster's (calibrated) speed readings. Each reading is timestamped and the start/finish
// crossings are interpolated between readings, so the result does not depend on how often
// the MCU reports speed. Best times are kept with LocalStorage (Car.settingsDb).
import QtQuick 2.14
import QtQuick.LocalStorage 2.0

QtObject {
    id: perf

    property var car

    property real best0100: 0          // seconds, 0 = none yet
    property real best80120: 0
    property real last0100: 0
    property real last80120: 0
    // the latest result, for the popup
    property string resultText: ""
    property int resultSeq: 0

    // run state
    property real prevT: 0
    property int prevV: 0
    property real stillSince: 0
    property bool run0: false
    property real start0: 0
    property int firstV: 0             // first moving reading, to back-date the start to 0 km/h
    property bool run8: false
    property real start8: 0

    function crossing(target, now, v) {   // when the speed passed [target], between readings
        if (v === prevV) return now
        return prevT + (now - prevT) * (target - prevV) / (v - prevV)
    }

    function finish(kind, seconds) {
        var key = kind === "0100" ? "best0100" : "best80120"
        var best = perf[key]
        var isBest = best === 0 || seconds < best
        if (kind === "0100") last0100 = seconds; else last80120 = seconds
        if (isBest) {
            perf[key] = seconds
            store(key, seconds)
        }
        resultText = (kind === "0100" ? "0–100 km/h  " : "80–120 km/h  ") + seconds.toFixed(2) + " s" +
                     (isBest ? "  ·  new best" : "  ·  best " + best.toFixed(2) + " s")
        resultSeq++
        console.log("[dash] perf " + kind + " " + seconds.toFixed(2) + " s" + (isBest ? " (best)" : ""))
    }

    function sample(v) {
        var now = Date.now()
        if (prevT === 0) { prevT = now; prevV = v; return }

        // 0–100: starts on the first movement after standing still for at least a second.
        // (Speed only changes when the car moves, so the standstill is timed from the first 0.)
        if (v === 0) {
            if (stillSince === 0) stillSince = now
            run0 = false
        } else {
            if (prevV === 0 && stillSince > 0 && now - stillSince >= 1000) {
                run0 = true; start0 = now; firstV = v
                stillSince = 0
                prevT = now; prevV = v
                return
            }
            stillSince = 0
        }
        if (run0 && firstV > 0 && v > firstV) {
            // back-date the start to when the car began rolling, extrapolating the first two
            // moving readings to 0 km/h (at most half a second)
            start0 -= Math.min(500, (now - start0) * firstV / (v - firstV))
            firstV = 0
        }
        if (run0) {
            if (v >= 100) {
                run0 = false
                finish("0100", (crossing(100, now, v) - start0) / 1000)
            } else if (v < prevV - 3 || now - start0 > 30000) {
                run0 = false                      // lifted off or gave up
            }
        }

        // 80–120: rolling, timed from passing 80 to passing 120 without dropping back
        if (!run8 && prevV < 80 && v >= 80 && v < 120) { run8 = true; start8 = crossing(80, now, v) }
        if (run8) {
            if (v >= 120) {
                run8 = false
                finish("80120", (crossing(120, now, v) - start8) / 1000)
            } else if (v < 78 || now - start8 > 40000) {
                run8 = false
            }
        }

        prevT = now
        prevV = v
    }

    function store(key, value) {
        try {
            car.settingsDb().transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO kv VALUES (?, ?)", [key, String(value)])
            })
        } catch (e) {
            console.warn("[dash] perf not stored: " + e)
        }
    }

    Component.onCompleted: {
        // speed starts at 0 without a change signal, so begin timing the standstill now
        if (car.speed === 0) { prevT = Date.now(); prevV = 0; stillSince = prevT }
        try {
            car.settingsDb().readTransaction(function(tx) {
                var r = tx.executeSql("SELECT k, v FROM kv WHERE k IN ('best0100', 'best80120')")
                for (var i = 0; i < r.rows.length; i++)
                    perf[r.rows.item(i).k] = parseFloat(r.rows.item(i).v) || 0
            })
        } catch (e) {}
    }

    property Connections speedWatch: Connections {
        target: perf.car
        onSpeedChanged: perf.sample(perf.car.speed)
    }
}
