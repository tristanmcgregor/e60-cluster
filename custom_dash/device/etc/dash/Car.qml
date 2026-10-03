// Live vehicle data from the CAN MCU via JLY's own EventHub plugin
// (libEventHub.so, already on the unit). Property names, groupings and the
// port/verified setup mirror what the stock Launcher's QML does.
//
// EventHub only emits one NOTIFY signal per group (speedChanged covers speed,
// speedM and rpm, etc.), so each handler copies the whole group out.
import QtQuick 2.14
import plugins.EventHub 1.0

Item {
    id: car

    // speed group (km/h, mph, rpm) - clamped like the stock UI
    property int speed: 0
    property int speedMph: 0
    // Calibration: the MCU's speed reads 6% low against GPS, so scale it up for display.
    property real speedFactor: 1.06
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
    // Indicator lamps as shown. The stock UI lights its arrows from turn*State (the blink phase);
    // as a fallback, when only the "indicator on" flags (turnLeft/turnRight) arrive, we blink them
    // ourselves at the normal flasher rate.
    property bool turnLeft: (turnLeftPhase || (turnLeftOn && blinkPhase))
    property bool turnRight: (turnRightPhase || (turnRightOn && blinkPhase))
    property bool turnLeftOn: false
    property bool turnRightOn: false
    property bool turnLeftPhase: false
    property bool turnRightPhase: false
    property bool blinkPhase: true
    Timer {
        interval: 380; repeat: true
        running: (car.turnLeftOn && !car.turnLeftPhase) || (car.turnRightOn && !car.turnRightPhase)
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
    // 26 single (BC); a hold arrives as code + 128.
    signal button(int code)

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
    property int lastButton: 0
    property bool buttonDown: false

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
        }
        onGearChanged: {
            car.gear = hub.gear
            car.gearShow = hub.gearShow
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
            car.doorFL = hub.lfDoor !== 0
            car.doorFR = hub.rfDoor !== 0
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
                car.buttonDown = true
            } else {
                car.buttonDown = false
                car.lastButton = hub.swcKey
                console.log("[dash] button " + hub.swcKey)
                car.button(hub.swcKey)
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
