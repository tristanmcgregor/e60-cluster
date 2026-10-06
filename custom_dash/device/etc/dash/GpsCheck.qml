// Compares the MCU's road speed with the head unit's GPS speed and learns the speed
// correction from it. The dash uses the learned value when the phone setting "Learn from
// GPS" is on (Car.speedAuto) and enough driving has been measured; until then, or with it
// off, the manual percentage applies. The HUD still gets the uncorrected MCU speed.
//
// Only steady driving counts: GPS above 40 km/h, accurate to 15 m, within 1.5 km/h of the
// previous fix, and GPS/MCU within 25 % of each other (drops tunnels and glitches). The
// correction is total GPS speed over total MCU speed, so long steady stretches weigh most.
// The totals are kept across drives; past an hour of samples they are halved, so a tyre
// change works its way in over a few drives.
import QtQuick 2.14

QtObject {
    id: check

    property var car
    property var nav

    readonly property int minSamples: 120        // two minutes of steady driving
    readonly property int maxSamples: 3600

    property real sumGps: 0
    property real sumRaw: 0
    property int samples: 0
    property real prevGps: -1
    property real relearnStamp: 0     // the phone's relearn stamp these totals started from
    property bool loaded: false
    // measured correction in percent (like the phone setting), NaN until enough samples
    readonly property real measured: samples >= minSamples ? (sumGps / sumRaw - 1) * 100 : NaN
    readonly property bool valid: !isNaN(measured) && measured > -10 && measured < 15

    function rawKph() {
        var hub = car.eventHub
        return hub ? Number(hub.speed) : 0
    }

    property Connections fixes: Connections {
        target: check.nav
        onGpsFix: {
            var g = check.nav.gpsKph, raw = check.rawKph()
            var steady = check.prevGps >= 0 && Math.abs(g - check.prevGps) < 1.5
            check.prevGps = g
            if (!steady || g < 40 || raw < 30 || check.nav.gpsAcc > 15) return
            if (g / raw < 0.8 || g / raw > 1.25) return
            check.sumGps += g
            check.sumRaw += raw
            check.samples++
            if (check.samples >= check.maxSamples) {
                check.sumGps /= 2; check.sumRaw /= 2; check.samples = Math.floor(check.samples / 2)
            }
            if (check.samples % 30 === 0) check.save()
        }
    }

    // learned value in use, rounded to 0.1 % so the factor only moves in visible steps
    onMeasuredChanged: if (valid) car.learnedCorrection = Math.round(measured * 10) / 10

    property Connections relearn: Connections {
        target: check.car
        onSpeedRelearnChanged: check.checkRelearn()
    }
    function checkRelearn() {
        if (!loaded || car.speedRelearn <= relearnStamp) return
        console.log("[dash] GPS speed check: relearning (phone setting)")
        relearnStamp = car.speedRelearn
        reset()
    }

    function reset() {
        sumGps = 0; sumRaw = 0; samples = 0
        car.learnedCorrection = NaN
        save()
    }

    function save() {
        try {
            car.settingsDb().transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO kv VALUES ('gpscheck', ?)",
                              [JSON.stringify({ sumGps: sumGps, sumRaw: sumRaw, samples: samples, relearn: relearnStamp })])
            })
        } catch (e) {}
    }

    Component.onCompleted: {
        try {
            car.settingsDb().readTransaction(function(tx) {
                var r = tx.executeSql("SELECT v FROM kv WHERE k = 'gpscheck'")
                if (!r.rows.length) return
                var s = JSON.parse(r.rows.item(0).v)
                sumGps = s.sumGps || 0; sumRaw = s.sumRaw || 0; samples = s.samples || 0
                relearnStamp = s.relearn || 0
            })
        } catch (e) {}
        loaded = true
        checkRelearn()
        if (valid) car.learnedCorrection = Math.round(measured * 10) / 10
        console.log("[dash] GPS speed check: " + samples + " samples" +
                    (valid ? ", learned " + measured.toFixed(1) + " %" : ""))
    }
}
