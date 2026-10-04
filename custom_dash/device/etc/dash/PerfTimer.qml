// Performance timer: 0–60 and 0–100 km/h from a standstill, from the cluster's (calibrated)
// speed readings. Each reading is timestamped and the crossings are interpolated between
// readings, so the result does not depend on how often the MCU reports speed.
//
// A run starts on the first movement after standing still for at least a second, and ends at
// 100 km/h, on lifting off (speed falling), or after 30 s. Every run is timed and can set a
// best; the result popup appears only in the sport layout by default (Car.perfPopups), so
// ordinary drives from traffic lights stay quiet. Best times are kept with LocalStorage.
import QtQuick 2.14
import QtQuick.LocalStorage 2.0

QtObject {
    id: perf

    property var car

    property real best060: 0           // seconds, 0 = none yet
    property real best0100: 0
    property real last060: 0
    property real last0100: 0
    // the latest result, for the popup
    property string resultText: ""
    property int resultSeq: 0

    // run state
    property real prevT: 0
    property int prevV: 0
    property real stillSince: 0
    property bool running: false
    property real start: 0
    property int firstV: 0             // first moving reading, to back-date the start to 0 km/h
    property real t60: 0               // this run's 0–60, 0 = not reached

    function crossing(target, now, v) {   // when the speed passed [target], between readings
        if (v === prevV) return now
        return prevT + (now - prevT) * (target - prevV) / (v - prevV)
    }

    function record(key, seconds) {       // returns true for a new best
        var best = perf[key]
        if (best !== 0 && seconds >= best) return false
        perf[key] = seconds
        store(key, seconds)
        return true
    }

    function endRun(t100) {
        running = false
        if (t60 <= 0) return               // never reached 60: nothing to show
        var parts = [], newBest = false
        last060 = t60
        if (record("best060", t60)) newBest = true
        parts.push("0–60 " + t60.toFixed(2) + " s")
        if (t100 > 0) {
            last0100 = t100
            if (record("best0100", t100)) newBest = true
            parts.push("0–100 " + t100.toFixed(2) + " s")
        }
        console.log("[dash] perf " + parts.join(", ") + (newBest ? " (best)" : ""))
        var mode = car.perfPopups
        if (mode === "always" || (mode === "sport" && car.sportMode)) {
            resultText = parts.join("  ·  ") + (newBest ? "\nNew best" : "")
            resultSeq++
        }
    }

    function sample(v) {
        var now = Date.now()
        if (prevT === 0) { prevT = now; prevV = v; return }

        if (v === 0) {
            if (stillSince === 0) stillSince = now
            if (running) endRun(0)
        } else {
            if (!running && prevV === 0 && stillSince > 0 && now - stillSince >= 1000) {
                running = true; start = now; firstV = v; t60 = 0
                stillSince = 0
                prevT = now; prevV = v
                return
            }
            stillSince = 0
        }
        if (running && firstV > 0 && v > firstV) {
            // back-date the start to when the car began rolling, extrapolating the first two
            // moving readings to 0 km/h (at most half a second)
            start -= Math.min(500, (now - start) * firstV / (v - firstV))
            firstV = 0
        }
        if (running) {
            if (t60 === 0 && v >= 60) t60 = (crossing(60, now, v) - start) / 1000
            if (v >= 100) endRun((crossing(100, now, v) - start) / 1000)
            else if (v < prevV - 3 || now - start > 30000) endRun(0)   // lifted off or gave up
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
                var r = tx.executeSql("SELECT k, v FROM kv WHERE k IN ('best060', 'best0100')")
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
