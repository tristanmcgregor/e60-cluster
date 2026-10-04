// Fuel bookkeeping for the FUEL page and the fuel-to-destination check.
//
// Every second: distance from the (calibrated) speed, and fuel used from the MCU's instant
// consumption (L/100km while moving, L/h when its unit says so). From that:
//  - a 30-minute consumption graph, one bar per minute (average L/100km while moving);
//  - "this tank": distance, litres, average and cost since the last refuel;
//  - a refuel log: a rise of 10 % or more in the fuel level starts a new tank (checked live
//    and against the level stored at the end of the last drive);
//  - fuel to destination: range against Android Auto's remaining route distance.
// Tank size, fuel price and the reserve margin come from the phone settings (Car).
import QtQuick 2.14
import QtQuick.LocalStorage 2.0

QtObject {
    id: fuel

    property var car
    property var nav

    // ---- consumption graph ----
    readonly property int minuteMs: typeof dashFastFuel !== "undefined" ? 250 : 60000
    property var history: []           // last 30 per-minute averages, L/100km (0 = no driving)
    property real bucketLitres: 0
    property real bucketKm: 0
    property real bucketStart: 0

    // ---- this tank ----
    property real tankKm: 0
    property real tankLitres: 0
    property string tankSince: ""
    readonly property real tankAvg: tankKm > 1 ? tankLitres / tankKm * 100 : 0
    readonly property real tankCost: tankLitres * car.fuelPrice
    readonly property real fuelLitres: car.fuelPercent / 100 * car.tankLitres
    property var log: []               // newest first: {date, km, avg, litres, cost}
    property int lastPercent: -1

    // ---- fuel to destination ----
    readonly property real rangeKm: parseFloat(car.range) || 0
    readonly property real destKm: nav.active && nav.totalDistanceM > 0 ? nav.totalDistanceM / 1000 : -1
    readonly property real arriveWithKm: destKm >= 0 && rangeKm > 0 ? rangeKm - destKm : NaN
    // ok | tight (arriving inside the reserve) | short (not enough range) | none (no route)
    readonly property string destStatus: isNaN(arriveWithKm) ? "none"
        : arriveWithKm < 0 ? "short" : arriveWithKm < car.fuelReserveKm ? "tight" : "ok"
    property string warnedStatus: "none"
    property string warnText: ""
    property bool warnCritical: false
    property int warnSeq: 0

    onDestStatusChanged: {
        if (destStatus === "none") { warnedStatus = "none"; return }
        // warn once per route, again only if it gets worse
        if ((destStatus === "tight" && warnedStatus === "none") ||
            (destStatus === "short" && warnedStatus !== "short")) {
            warnedStatus = destStatus
            warnCritical = destStatus === "short"
            warnText = (destStatus === "short" ? "Not enough fuel for this route" : "Low fuel at the destination") +
                       "\nRange " + Math.round(rangeKm) + " km  ·  " + Math.round(destKm) + " km to go"
            warnSeq++
        }
    }

    property real lastT: 0
    function tick() {
        var now = Date.now()
        if (lastT === 0) { lastT = now; bucketStart = now; return }
        var dt = (now - lastT) / 1000
        lastT = now
        // the desktop preview runs time 200x faster so a tank's worth of driving shows up
        var v = car.speed, km = v * dt / 3600 * (typeof dashFastFuel !== "undefined" ? 200 : 1)
        var inst = parseFloat(car.instantFuel) || 0
        var litres = car.instantFuelUnit.indexOf("/h") >= 0 ? inst * dt / 3600
                   : (v > 3 ? inst * km / 100 : 0)
        tankKm += km; tankLitres += litres
        bucketKm += km; bucketLitres += litres
        if (now - bucketStart >= minuteMs) {
            var h = history.slice(-29)
            h.push(bucketKm > 0.05 ? bucketLitres / bucketKm * 100 : 0)
            history = h
            bucketKm = 0; bucketLitres = 0; bucketStart = now
            save()
        }
    }

    function checkRefuel(percent) {
        if (percent <= 0) return
        if (lastPercent >= 0 && percent - lastPercent >= 10) {
            if (tankKm > 5) {
                var l = log.slice(0, 9)
                l.unshift({ date: tankSince, km: Math.round(tankKm), avg: tankAvg, litres: tankLitres, cost: tankCost })
                log = l
            }
            console.log("[dash] refuel detected (" + lastPercent + "% -> " + percent + "%)")
            tankKm = 0; tankLitres = 0
            tankSince = Qt.formatDate(new Date(), "d MMM")
        }
        lastPercent = percent
        save()
    }

    function save() {
        try {
            car.settingsDb().transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO kv VALUES ('fuel', ?)", [JSON.stringify({
                    tankKm: tankKm, tankLitres: tankLitres, tankSince: tankSince,
                    log: log, lastPercent: lastPercent, history: history })])
            })
        } catch (e) {}
    }

    Component.onCompleted: {
        try {
            car.settingsDb().readTransaction(function(tx) {
                var r = tx.executeSql("SELECT v FROM kv WHERE k = 'fuel'")
                if (!r.rows.length) return
                var s = JSON.parse(r.rows.item(0).v)
                tankKm = s.tankKm || 0; tankLitres = s.tankLitres || 0; tankSince = s.tankSince || ""
                log = s.log || []; lastPercent = s.lastPercent === undefined ? -1 : s.lastPercent
                history = s.history || []
            })
        } catch (e) {}
        if (tankSince === "") tankSince = Qt.formatDate(new Date(), "d MMM")
        if (car.fuelPercent > 0) checkRefuel(car.fuelPercent)
    }

    property Timer ticker: Timer { interval: 1000; running: true; repeat: true; onTriggered: fuel.tick() }
    property Connections fuelWatch: Connections {
        target: fuel.car
        onFuelPercentChanged: fuel.checkRefuel(fuel.car.fuelPercent)
    }
}
