// Compares the MCU's road speed with the head unit's GPS speed, to check the dash's speed
// correction (and to size the HUD's, which gets the MCU speed uncorrected). Shown on the
// developer page; it keeps counting while that page is closed.
//
// Only steady driving counts: GPS above 40 km/h, accurate to 15 m, and within 1.5 km/h of
// the previous fix. The measured correction is total GPS speed over total MCU speed, so long
// steady stretches weigh most.
import QtQuick 2.14

QtObject {
    id: check

    property var car
    property var nav

    property real sumGps: 0
    property real sumRaw: 0
    property int samples: 0
    property real prevGps: -1
    // measured correction in percent (like the phone setting), NaN until enough samples
    readonly property real measured: samples >= 30 ? (sumGps / sumRaw - 1) * 100 : NaN

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
            check.sumGps += g
            check.sumRaw += raw
            check.samples++
        }
    }

    function reset() { sumGps = 0; sumRaw = 0; samples = 0 }
}
