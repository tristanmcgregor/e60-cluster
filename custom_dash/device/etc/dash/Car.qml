// Live vehicle data from the CAN MCU via JLY's own EventHub plugin
// (libEventHub.so, already on the unit). Property names, groupings and the
// port/verified setup mirror what the stock Launcher's QML does.
//
// EventHub only emits one NOTIFY signal per group (speedChanged covers speed,
// speedM and rpm, etc.), so each handler copies the whole group out.
import QtQuick 2.14
import QtQuick.LocalStorage 2.0
import "."
import plugins.EventHub 1.0

Item {
    id: car

    // speed group (km/h, mph, rpm) - clamped like the stock UI
    property int speed: 0
    property int speedMph: 0
    // Calibration: the MCU's speed reads about 6% high, so scale it down for display.
    // speedFactor is the learned GPS correction (GpsCheck) when "Learn from GPS" is on and
    // enough steady driving has been measured, else the manual percentage.
    property real manualCorrection: -6
    property bool speedAuto: true
    property real learnedCorrection: NaN
    property real speedRelearn: 0        // phone "Start learning again" stamp; GpsCheck resets on a new one
    readonly property bool usingLearned: speedAuto && !isNaN(learnedCorrection)
    readonly property real speedFactor: 1 + (usingLearned ? learnedCorrection : manualCorrection) / 100
    property int rpm: 0

    // fuel group
    property int fuelPercent: 0
    property string range: ""
    property string rangeMiles: ""

    // coolant group
    property int coolantPercent: 0
    property string coolantTemp: ""
    property string coolantTempF: ""

    // trip group
    property string odo: ""
    property string odoMiles: ""
    property string tripA: ""
    property string tripAMiles: ""

    // dashboard group
    property string outsideTemp: ""
    property string oilTemp: ""
    property int oilTempInt: 0
    property int batteryVoltage: 0

    property string gear: ""
    property bool gearShow: true
    // Indicator lamps as shown. The MCU reports two things per side: turn* ("indicator on")
    // and turn*State (the flasher's lamp phase). While the phase is actually flashing it drives
    // the arrow. Only when the indicator is on and the phase has not changed for 1.5 s (no phase
    // reported, or stuck lit) do we blink the arrow ourselves at the normal flasher rate.
    // (The old fallback restarted its own blink, lit, on every dark phase, which held normal
    // indicators steadily on; hazards, which report the phase without "on", blinked fine.)
    property bool turnLeft: leftFlashing ? turnLeftPhase : ((turnLeftOn || turnLeftPhase) && blinkPhase)
    property bool turnRight: rightFlashing ? turnRightPhase : ((turnRightOn || turnRightPhase) && blinkPhase)
    property bool turnLeftOn: false
    property bool turnRightOn: false
    property bool turnLeftPhase: false
    property bool turnRightPhase: false
    property bool leftFlashing: false      // phase changed within the last 1.5 s
    property bool rightFlashing: false
    property bool blinkPhase: true
    onTurnLeftPhaseChanged: { leftFlashing = true; leftFlashWatch.restart() }
    onTurnRightPhaseChanged: { rightFlashing = true; rightFlashWatch.restart() }
    Timer { id: leftFlashWatch; interval: 1500; onTriggered: car.leftFlashing = false }
    Timer { id: rightFlashWatch; interval: 1500; onTriggered: car.rightFlashing = false }
    Timer {
        interval: 380; repeat: true
        running: (!car.leftFlashing && (car.turnLeftOn || car.turnLeftPhase)) ||
                 (!car.rightFlashing && (car.turnRightOn || car.turnRightPhase))
        onTriggered: car.blinkPhase = !car.blinkPhase
        onRunningChanged: car.blinkPhase = true
    }
    property bool useMph: false

    // warning lights: alarmStates[id] = 0 off, 1 on, 2 fast flash, 3 slow flash (ids in Alarms.js)
    property var alarmStates: []
    property var activeAlarms: []          // ids with state != 0, in table order
    // one-shot warning popup
    property int warningId: 0
    property int warningMs: 0
    property int warningSeq: 0              // bumps on every new warning so repeats re-show

    property bool doorFL: false
    property bool doorFR: false
    property bool doorRL: false
    property bool doorRR: false
    property bool trunkOpen: false
    property bool hoodOpen: false
    readonly property bool anyDoorOpen: doorFL || doorFR || doorRL || doorRR || trunkOpen || hoodOpen

    // ignition: drives the start-up / shut-down animation (stock UI treats acc == 1 as on)
    property bool ignitionOn: true

    // Service items pushed by the MCU one at a time (maintainItemId selects the item).
    // Names follow the order of the stock Launcher's item table.
    readonly property var serviceNames: ["Oil and oil filter", "Front brake pads", "Vehicle inspection",
                                         "Brake fluid", "Rear brake pads", "Air and fuel filter",
                                         "Custom item 1", "Custom item 2"]
    property var service: ({})               // id -> { state, mileage, reminder, date }
    property int serviceSeq: 0
    property int serviceAlertId: -1          // item to remind about now
    property int serviceAlertMs: 0
    property int serviceAlertSeq: 0

    // Steering-wheel / stalk buttons. Like the stock UI, a press is reported on release.
    // Codes (from the stock Launcher): 19 up, 20 down, 21 left, 22 right, 23 enter,
    // 26 single (BC). A hold is reported as code + 128: the dash times the press itself
    // (held holdMs, sent while still held, the release then swallowed), and also passes on
    // a code + 128 if the MCU sends one.
    signal button(int code)
    readonly property int holdMs: 800

    // ---- warm-up redline, shift lights, sport layout ----
    // Defaults; the phone settings page (CarSettings on the head unit) can replace them.
    // Warm-up redline from engine oil temperature: [°C, rpm] rows, linear between rows and
    // flat beyond the first and last (7250 is the normal limit once warm).
    property var redlineTable: [[20, 4500], [40, 5166], [50, 5500], [60, 6000], [70, 6500], [80, 6875], [90, 7250]]
    property string perfPopups: "sport"     // timer results: sport (layout) | always | off
    property bool shiftLightsOn: true
    property int shiftWindow: 2000      // lights start this far below the shift point
    property int shiftMargin: 200       // flash this far below the redline
    property string sportSetting: "auto"   // auto (gearbox in S or M) | always | never

    // Oil temperature when the MCU reports it, otherwise coolant; 0 = unknown.
    readonly property int engineTemp: oilTempInt > 0 ? oilTempInt : (parseInt(coolantTemp) || 0)
    readonly property int redlineRpm: {
        var t = redlineTable
        if (!t.length) return 7250
        if (engineTemp <= 0) return t[t.length - 1][1]          // temperature unknown: normal limit
        if (engineTemp <= t[0][0]) return t[0][1]
        for (var i = 1; i < t.length; i++) {
            if (engineTemp <= t[i][0]) {
                var f = (engineTemp - t[i - 1][0]) / (t[i][0] - t[i - 1][0])
                return Math.round(t[i - 1][1] + f * (t[i][1] - t[i - 1][1]))
            }
        }
        return t[t.length - 1][1]
    }
    readonly property int shiftRpm: redlineRpm - shiftMargin
    // S or M on the selector. TODO(after the Phase 0 drive): confirm this car's gear strings.
    readonly property bool gearboxSport: /^(DS|S|M)\d*$/i.test(gear.trim())
    readonly property bool sportMode: sportSetting === "always" || (sportSetting === "auto" && gearboxSport)

    // fuel page and fuel-to-destination (FuelTracker)
    property real tankLitres: 70         // E60 525i
    property real fuelPrice: 2.0         // per litre, for cost per tank
    property int fuelReserveKm: 30       // warn when arriving with less range than this
    property bool mapAuto: false         // full-screen map whenever a route starts
    property int speedLimitMargin: 3
    property bool speedLimitOn: true
    property bool cameraAlertsOn: true      // the head unit also stops sending when this is off
    property int defaultPage: 0
    signal settingsApplied()

    // Settings from the phone settings page (head unit CarSettings). Applied live, and kept
    // with LocalStorage so the next start-up uses them before the head unit is reachable.
    function applySettings(s, store) {
        // settings without a version come from head unit builds whose default was +6 %; that
        // default is now -6 % (CarSettings version 2), so a +6 from them is read as -6
        if (s.speedCorrection !== undefined)
            manualCorrection = s.version === undefined && Number(s.speedCorrection) === 6 ? -6 : Number(s.speedCorrection)
        if (s.speedAuto !== undefined) speedAuto = s.speedAuto === true
        if (s.speedRelearn !== undefined) speedRelearn = Number(s.speedRelearn) || 0
        if (s.sport !== undefined) sportSetting = s.sport
        if (s.shiftLights !== undefined) shiftLightsOn = s.shiftLights === true
        if (s.shiftWindow !== undefined) shiftWindow = s.shiftWindow
        if (s.shiftMargin !== undefined) shiftMargin = s.shiftMargin
        if (s.redline !== undefined && s.redline.length) redlineTable = s.redline
        if (s.speedLimit !== undefined) speedLimitOn = s.speedLimit === true
        if (s.speedLimitMargin !== undefined) speedLimitMargin = s.speedLimitMargin
        if (s.cameraAlerts !== undefined) cameraAlertsOn = s.cameraAlerts === true
        if (s.defaultPage !== undefined) defaultPage = s.defaultPage
        if (s.perfPopups !== undefined) perfPopups = s.perfPopups
        if (s.tankLitres !== undefined) tankLitres = s.tankLitres
        if (s.fuelPrice !== undefined) fuelPrice = s.fuelPrice
        if (s.fuelReserveKm !== undefined) fuelReserveKm = s.fuelReserveKm
        if (s.mapAuto !== undefined) mapAuto = s.mapAuto === true
        if (s.theme !== undefined) Theme.classic = s.theme === "classic"
        settingsApplied()
        if (store) {
            try {
                settingsDb().transaction(function(tx) {
                    tx.executeSql("INSERT OR REPLACE INTO kv VALUES ('settings', ?)", [JSON.stringify(s)])
                })
            } catch (e) {
                console.warn("[dash] settings not stored: " + e)
            }
        }
        console.log("[dash] settings applied" + (store ? " and stored" : " (stored copy)"))
    }
    function settingsDb() {
        var db = LocalStorage.openDatabaseSync("e60dash", "1.0", "E60 dash settings", 64 * 1024)
        db.transaction(function(tx) { tx.executeSql("CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY, v TEXT)") })
        return db
    }
    Component.onCompleted: {
        try {
            settingsDb().readTransaction(function(tx) {
                var r = tx.executeSql("SELECT v FROM kv WHERE k = 'settings'")
                if (r.rows.length) car.applySettings(JSON.parse(r.rows.item(0).v), false)
            })
        } catch (e) {
            console.warn("[dash] no stored settings: " + e)
        }
    }

    // The EventHub object itself, for the developer page (read-only use).
    readonly property QtObject eventHub: hub

    // Menu page currently shown, as the stock Launcher's EventHub.MenuId values. Writing
    // hub.menuId makes EventHub send the MCU its "interface" packet (UI style, menu, window);
    // the stock UI does this at start-up and on every page change, and the MCU relies on it
    // for the HUD. 257 MENU_TRIP_RESET, 519 MENU_VEHICLE_MAINTAIN, 769 MENU_NAVIGATION_AA,
    // 1030 MENU_SETTINGS_VERSION.
    property int menuId: 257
    function reportMenu() {
        hub.menuId = car.menuId
        console.log("[dash] menuId " + car.menuId + " uiStyle " + hub.uiStyle)
    }
    onMenuIdChanged: reportMenu()
    // The stock UI's pages report on creation, a moment after start-up; repeat once then too.
    Timer { interval: 2000; running: true; onTriggered: car.reportMenu() }
    property string hubVersion: ""
    property string mcuVersion: ""
    // What the MCU reports for the gearbox and oil, logged on change: the sport layout and
    // the warm-up redline depend on values only a drive in D, S and M can show.
    property string lastDrivetrainLog: ""
    function logDrivetrain() {
        var line = "gear \"" + hub.gear + "\" auto=" + hub.gearAuto + " manual=" + hub.gearManual +
                   " oil=" + hub.oilTempInt + " coolant=" + hub.waterTemperature
        if (line !== lastDrivetrainLog) {
            lastDrivetrainLog = line
            console.log("[dash] " + line)
        }
    }

    property int lastButton: 0
    property bool buttonDown: false
    property int pressCode: 0            // code seen with the press, 0 if the MCU sent none
    property bool holdSent: false
    Timer {
        id: holdTimer
        interval: car.holdMs
        onTriggered: {
            var c = car.pressCode || hub.swcKey
            if (!car.buttonDown || c <= 0 || c >= 128) return
            car.holdSent = true
            car.pressCode = c
            car.sendButton(c + 128)
        }
    }
    function sendButton(code) {
        lastButton = code
        console.log("[dash] button " + code)
        button(code)
    }

    // fuel group extras
    property string instantFuel: ""
    property string instantFuelUnit: ""
    property string tripB: ""
    property string tripBMiles: ""

    // cruise control
    property bool cruiseActive: false
    property string cruiseSetSpeed: ""

    // trip computer since last reset
    property string avgFuel: ""
    property string avgSpeed: ""
    property string tripDistance: ""
    property string tripTime: ""

    // tyre pressures (strings as formatted by the MCU) and their alarm states
    property var tyres: ["", "", "", ""]          // FL, FR, RL, RR
    property var tyreStates: [0, 0, 0, 0]

    EventHub {
        id: hub
        port: 2          // /dev/ttyS2, same literal as the stock Launcher
        packetDebug: 0

        onSpeedChanged: {
            car.speed = Math.min(Math.round(hub.speed * car.speedFactor), 330)
            car.speedMph = Math.min(Math.round(hub.speedM * car.speedFactor), 200)
            car.rpm = Math.min(hub.rpm, 8500)
        }
        onFuelChanged: {
            car.fuelPercent = hub.fuel
            car.range = hub.remindingRange
            car.rangeMiles = hub.remindingRangeM
            car.instantFuel = hub.instantFuel
            car.instantFuelUnit = hub.instantFuelUnit
        }
        onWaterChanged: {
            car.coolantPercent = hub.waterPercetage
            car.coolantTemp = hub.waterTemperature
            car.coolantTempF = hub.waterTemperatureF
        }
        onTripChanged: {
            car.odo = hub.odo
            car.odoMiles = hub.odoM
            car.tripA = hub.tripA
            car.tripAMiles = hub.tripAmile
            car.tripB = hub.tripB
            car.tripBMiles = hub.tripBmile
        }
        onDashboardChanged: {
            car.outsideTemp = hub.outsideTemp
            car.oilTemp = hub.oilTemp
            car.oilTempInt = hub.oilTempInt
            car.batteryVoltage = hub.batteryVoltage
            car.logDrivetrain()
        }
        onGearChanged: {
            car.gear = hub.gear
            car.gearShow = hub.gearShow
            car.logDrivetrain()
        }
        onTurnChanged: {
            car.turnLeftOn = hub.turnLeft
            car.turnRightOn = hub.turnRight
            car.turnLeftPhase = hub.turnLeftState
            car.turnRightPhase = hub.turnRightState
            console.log("[dash] turn L=" + hub.turnLeft + " R=" + hub.turnRight +
                        " Lstate=" + hub.turnLeftState + " Rstate=" + hub.turnRightState)
        }
        onUnitChanged: car.useMph = hub.MPH === 1

        // Same read protocol as the stock Launcher: write each index into
        // alarmTable, read the state back. The stock UI skips index 30.
        onAlarmTableChanged: {
            var n = hub.alarmTableMax
            var st = [], act = []
            for (var i = 1; i < n; i++) {
                if (i === 30) continue
                hub.alarmTable = i
                st[i] = hub.alarmTable
                if (st[i]) act.push(i)
            }
            car.alarmStates = st
            car.activeAlarms = act
        }
        onWarningChanged: {
            car.warningId = hub.warningId
            car.warningMs = hub.warningDuration * 1000
            car.warningSeq++
        }
        onDoorChanged: {
            // this car's MCU reports the front doors swapped (opening the driver's door, front
            // right, shows as lfDoor); the rear doors are the right way round
            car.doorFL = hub.rfDoor !== 0
            car.doorFR = hub.lfDoor !== 0
            car.doorRL = hub.lrDoor !== 0
            car.doorRR = hub.rrDoor !== 0
            car.trunkOpen = hub.trunk !== 0
            car.hoodOpen = hub.hood !== 0
        }
        onVersionNotify: {
            car.hubVersion = hub.version
            car.mcuVersion = hub.canVersion
        }
        onSwcChanged: {
            if (hub.swcKeyPress) {
                if (car.buttonDown) return          // repeated while held
                car.buttonDown = true
                car.holdSent = false
                car.pressCode = hub.swcKey
                holdTimer.restart()
                console.log("[dash] button " + hub.swcKey + " down")
            } else {
                var code = hub.swcKey
                car.buttonDown = false
                holdTimer.stop()
                if (car.holdSent) {
                    car.holdSent = false
                    // the hold already went out; the release (plain or + 128) is not a second press
                    if (code === car.pressCode || code === car.pressCode + 128) return
                }
                car.sendButton(code)
            }
        }
        onCruiseChanged: {
            car.cruiseActive = hub.cruiseShowSetSpeed !== 0 || hub.cruiseShowCtrlIndicator !== 0
            car.cruiseSetSpeed = hub.cruiseSetSpeed
        }
        onResetChanged: {
            car.avgFuel = hub.resetAvgFuel
            car.avgSpeed = hub.resetAvgSpeed
            car.tripDistance = hub.resetDistance
            car.tripTime = hub.resetDuration
        }
        onTpmsChanged: {
            car.tyres = [hub.flTire, hub.frTire, hub.rlTire, hub.rrTire]
            car.tyreStates = [hub.flTireState, hub.frTireState, hub.rlTireState, hub.rrTireState]
        }
        onAccChanged: {
            car.ignitionOn = hub.acc === 1
            if (car.ignitionOn) car.reportMenu()     // MCU may have restarted with the ignition
        }
        onMaintainChanged: {
            var id = hub.maintainItemId
            var all = car.service
            all[id] = { state: hub.maintainState, mileage: hub.maintainMileage, reminder: hub.maintainReminder,
                        date: hub.maintainYear !== "" ? hub.maintainDay + "/" + hub.maintainMonth + "/" + hub.maintainYear : "" }
            car.service = all
            car.serviceSeq++
            if (hub.maintainDuration > 0) {
                car.serviceAlertId = id
                car.serviceAlertMs = hub.maintainDuration * 1000
                car.serviceAlertSeq++
            }
        }

        Component.onCompleted: {
            hub.MPH = 0
            hub.verified = 1000
            car.reportMenu()
        }
    }
}
