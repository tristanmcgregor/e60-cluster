// Custom 1920x720 cluster layout modelled on the 2018+ Range Rover virtual instrument
// panel: two beaded dials, a landscape band between two hairlines, a status row on top
// and odometer / range underneath. All data comes from Car.qml and Nav.qml.
import QtQuick 2.14
import QtQuick.Window 2.14
import "."
import "Units.js" as Units

Window {
    id: win
    visible: true
    width: 1920
    height: 720
    color: "#000000"
    title: "dash"

    property alias car: car
    Car { id: car }
    PerfTimer { id: perfTimer; car: car }
    CarWarnings { id: carWarnings; car: car }
    Nav {
        id: navData
        onSettingsReceived: car.applySettings(settings, true)
    }

    // Fixed 1920x720 design surface; scale is 1 on the cluster, <1 in the desktop preview.
    Item {
    id: stage
    width: 1920
    height: 720
    scale: Math.min(win.width / 1920, win.height / 720)
    transformOrigin: Item.TopLeft

    property real rpmShown: car.rpm
    Behavior on rpmShown { NumberAnimation { duration: 120 } }
    property real speedNeedle: speedShown
    Behavior on speedNeedle { NumberAnimation { duration: 150 } }

    readonly property int speedShown: car.useMph ? car.speedMph : car.speed

    // ── start-up / shut-down: fade from black and sweep both needles to full scale and back
    property real reveal: 0          // 0 = black, 1 = dash visible
    property real sweep: 0           // 0..1 of full scale while sweeping
    property bool sweeping: false
    property real gearOffset: 0       // moves the gear text so its capitals sit on the dial centre

    SequentialAnimation {
        id: startup
        ScriptAction { script: { stage.sweeping = true; stage.sweep = 0 } }
        NumberAnimation { target: stage; property: "reveal"; to: 1; duration: 600; easing.type: Easing.OutQuad }
        NumberAnimation { target: stage; property: "sweep"; to: 1; duration: 700; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 150 }
        NumberAnimation { target: stage; property: "sweep"; to: 0; duration: 700; easing.type: Easing.InOutCubic }
        ScriptAction { script: stage.sweeping = false }
    }
    SequentialAnimation {
        id: shutdown
        ScriptAction { script: { startup.stop(); stage.sweeping = true; stage.sweep = 0 } }
        PauseAnimation { duration: 400 }
        NumberAnimation { target: stage; property: "reveal"; to: 0; duration: 900; easing.type: Easing.InQuad }
    }
    Component.onCompleted: startup.start()
    Connections {
        target: car
        onIgnitionOnChanged: {
            if (car.ignitionOn) { shutdown.stop(); startup.start() }
            else shutdown.start()
        }
    }
    readonly property string fontName: Theme.font
    readonly property string iconBase: typeof dashIconBase !== "undefined" ? dashIconBase : "qrc:/"

    // geometry taken from the reference photo
    readonly property real dialSize: 600
    readonly property real dialY: 395
    readonly property real speedoX: 382
    readonly property real tachX: 1538
    readonly property real lineTop: 152
    readonly property real lineBottom: 636


    // ── landscape band between the two hairlines (drawn, not a photo)
    Item {
        x: 560; y: stage.lineTop
        width: 800; height: stage.lineBottom - stage.lineTop
        clip: true
        Rectangle {          // sky
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.00; color: "#3f4347" }
                GradientStop { position: 0.40; color: "#6b7074" }
                GradientStop { position: 0.57; color: "#9da2a6" }   // horizon haze
                GradientStop { position: 0.60; color: "#4a4e52" }
                GradientStop { position: 0.75; color: "#2a2d30" }
                GradientStop { position: 1.00; color: "#121314" }   // ground
            }
        }
        Canvas {             // low distant ridge on the horizon
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var h = height * 0.585
                ctx.fillStyle = "#666b70"
                ctx.beginPath()
                ctx.moveTo(0, h)
                var pts = [0.08, -6, 0.2, -2, 0.32, -10, 0.45, -4, 0.6, -9, 0.74, -3, 0.88, -7, 1.0, -2]
                for (var i = 0; i < pts.length; i += 2) ctx.lineTo(width * pts[i], h + pts[i + 1])
                ctx.lineTo(width, h + 4); ctx.lineTo(0, h + 4)
                ctx.closePath(); ctx.fill()
            }
        }
        Rectangle {          // fade the band into black at both ends
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "#ff000000" }
                GradientStop { position: 0.16; color: "#00000000" }
                GradientStop { position: 0.84; color: "#00000000" }
                GradientStop { position: 1.00; color: "#ff000000" }
            }
        }
    }

    // Darken the whole landscape band behind text pages (edges sit under the dials, so no seams);
    // cleared on the Navigation page so the live map shows at full brightness.
    Rectangle {
        x: 560; y: stage.lineTop + 2
        width: 800; height: stage.lineBottom - stage.lineTop - 4
        color: "#000000"
        opacity: centreMenu.onNavPage ? 0 : 0.72
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }
    // ── live Android Auto map: fills the band, edges tucked behind the dials (drawn after it)
    Loader {
        id: mapLoader
        x: 560; y: stage.lineTop + 2
        width: 800; height: stage.lineBottom - stage.lineTop - 4
        active: navData.gateway !== ""
        source: "ClusterMap.qml"
        visible: status === Loader.Ready && item.streaming && centreMenu.onNavPage && !car.sportMode
        onLoaded: item.host = Qt.binding(function() { return navData.gateway })
        onStatusChanged: if (status === Loader.Error) console.warn("[dash] cluster map unavailable; using the directions card")
    }

    // ── the two hairlines that run the width of the panel
    Repeater {
        model: [stage.lineTop, stage.lineBottom]
        Rectangle { x: 40; y: modelData; width: 1840; height: 2; color: "#4a4f55" }
    }

    // ── speedometer
    JlrDial {
        id: speedo
        x: stage.speedoX - size / 2; y: stage.dialY - size / 2
        size: stage.dialSize
        maxValue: car.useMph ? 180 : 280
        majorStep: car.useMph ? 10 : 20
        minorPerMajor: 2
        alternateDim: true
        scaleLabel: car.useMph ? "mph" : "km/h"
        value: stage.sweeping ? stage.sweep * maxValue : stage.speedNeedle
        gapFrac: car.fuelPercent / 100
        gapWarn: car.fuelPercent <= 12
        gapIcon: "fuel"
        gapLowColor: "#e0453a"
        gapHighColor: "#e0453a"

        Column {
            anchors.centerIn: parent
            spacing: 0
            Item {                       // cruise badge where the photo has its badge
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160; height: 44
                Text {
                    anchors.centerIn: parent
                    visible: car.cruiseActive
                    text: "◎ " + car.cruiseSetSpeed
                    color: Theme.ok
                    font.pixelSize: 30
                    font.family: stage.fontName
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: stage.speedShown
                color: stage.overLimit ? Theme.critical : "#f4f6f8"
                font.pixelSize: 100
                font.family: stage.fontName
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: car.useMph ? "mph" : "km/h"
                opacity: stage.limitShown > 0 ? 0 : 1        // the limit sign sits here instead
                color: "#aeb5bd"
                font.pixelSize: 22
                font.family: stage.fontName
            }
        }
    }

    // speed limit of the current road (head unit GPS + OpenStreetMap), below the digital speed
    readonly property int limitShown: !car.speedLimitOn || navData.speedLimitKph <= 0 ? 0
        : (car.useMph ? Math.round(navData.speedLimitKph / 1.609) : navData.speedLimitKph)
    readonly property bool overLimit: limitShown > 0 && !stage.sweeping &&
        stage.speedShown > limitShown + (car.useMph ? Math.round(car.speedLimitMargin / 1.609) : car.speedLimitMargin)
    LimitSign {                                       // takes the place of the "km/h" label
        x: stage.speedoX - width / 2
        y: stage.dialY + 70
        limit: stage.limitShown
        over: stage.overLimit
    }

    // ── tachometer
    JlrDial {
        id: tach
        x: stage.tachX - size / 2; y: stage.dialY - size / 2
        size: stage.dialSize
        maxValue: 8000
        majorStep: 1000
        minorPerMajor: 2
        labelDivisor: 1000
        alternateDim: false
        redFrom: car.redlineRpm                       // follows oil temperature while warming up
        ringColor: car.sportMode ? Theme.sportAccent : "#d9dde2"
        needleColor: car.sportMode ? Theme.sportAccent : "#ffffff"
        scaleLabel: "rpm x 1000"
        value: stage.sweeping ? stage.sweep * maxValue : stage.rpmShown
        gapFrac: car.coolantPercent / 100
        gapWarn: car.coolantPercent >= 90
        gapIcon: "temp"
        gapLowColor: "#8a7cff"       // cold end: blue/violet like the reference
        gapHighColor: "#e0453a"      // hot end: red

        Text {                          // gear, centred on the dial (offset: cap-height centring)
            id: gearText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: stage.gearOffset
            text: car.gearShow && car.gear !== "" ? car.gear : "P"
            color: car.gear === "R" ? Theme.critical : "#f4f6f8"
            font.pixelSize: 100
            font.family: stage.fontName
        }
        Row {                           // engine warming up: cold oil, redline still lowered
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: gearText.bottom
            anchors.topMargin: 2
            spacing: 8
            visible: car.oilTempInt > 0 && car.oilTempInt < 70 && car.rpm > 300
            Image { width: 26; height: 26; source: "icons/warmup.png"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "WARMING UP  " + car.oilTempInt + "°C"
                color: "#8a7cff"
                font.pixelSize: 20
                font.family: stage.fontName
                font.letterSpacing: 1
            }
        }
    }

    // ── status row: clock, warning lights, indicators, outside temperature
    Text {
        id: clock
        x: 640 - width; y: 104
        color: "#e9edf2"; font.pixelSize: 30; font.family: stage.fontName
        text: Qt.formatTime(new Date(), "hh:mm")
        Timer { interval: 10000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm") }
    }
    AlarmBar {
        x: 700; y: 98
        ids: car.activeAlarms
        states: car.alarmStates
        iconBase: stage.iconBase
        iconSize: 40
        maxIcons: 8
    }
    Text {
        x: 1280; y: 104
        text: car.outsideTemp
        color: "#e9edf2"; font.pixelSize: 30; font.family: stage.fontName
    }
    Image {
        x: 650; y: 100; width: 42; height: 42; smooth: true
        source: car.turnLeft ? "icons/turn_left_on.png" : "icons/turn_left_off.png"
        visible: car.turnLeft
    }
    Image {
        x: 1920 - 650 - width; y: 100; width: 42; height: 42; smooth: true
        source: car.turnRight ? "icons/turn_right_on.png" : "icons/turn_right_off.png"
        visible: car.turnRight
    }

    // ── centre band: menu pages (live map behind on the Navigation page); popup and doors on top
    // sport layout (gearbox in S or M): shift lights on the top hairline, sport card in the centre
    ShiftLights {
        x: 600; y: stage.lineTop + 8
        width: 720
        visible: opacity > 0.01
        opacity: car.sportMode && car.shiftLightsOn && !stage.sweeping ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        rpm: car.rpm
        shiftRpm: car.shiftRpm
        window: car.shiftWindow
    }
    SportCard {
        x: 700; y: stage.lineTop + 2
        car: car
        perf: perfTimer
        visible: opacity > 0.01
        opacity: car.sportMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    CentreMenu {
        id: centreMenu
        visible: opacity > 0.01
        opacity: car.sportMode ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 300 } }
        x: 700; y: stage.lineTop + 2
        width: 520; height: stage.lineBottom - stage.lineTop - 4
        car: car
        nav: navData
        mph: car.useMph
        mapStreaming: mapLoader.status === Loader.Ready && mapLoader.item.streaming
        dimmed: popup.shown || servicePopup.shown || carWarningPopup.shown || perfPopup.shown
    }
    WarningPopup {
        id: popup
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.lineBottom - height - 26
        alarmId: car.warningId
        durationMs: car.warningMs
        seq: car.warningSeq
        iconBase: stage.iconBase
        fontName: stage.fontName
    }
    WarningPopup {       // service reminder, same strip style as check-control messages
        id: servicePopup
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.lineBottom - height - 26
        visible: opacity > 0.01 && !popup.shown
        customIcon: "icons/service.png"
        customText: {
            var id = car.serviceAlertId
            if (id < 0) return ""
            var item = car.service[id] || {}
            var name = car.serviceNames[id] || ("Service item " + id)
            var due = item.reminder || item.mileage || ""
            return due !== "" ? name + " \u2014 " + due : name + " \u2014 service due"
        }
        durationMs: car.serviceAlertMs
        seq: car.serviceAlertSeq
    }
    WarningPopup {       // our own warnings: temperatures, charging, battery
        id: carWarningPopup
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.lineBottom - height - 26
        visible: opacity > 0.01 && !popup.shown
        forceCritical: true
        customText: carWarnings.text
        customIcon: carWarnings.icon
        durationMs: 10000
        seq: carWarnings.seq
    }
    WarningPopup {       // performance timer result
        id: perfPopup
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.lineBottom - height - 26
        visible: opacity > 0.01 && !popup.shown && !carWarningPopup.shown
        customText: perfTimer.resultText
        customIcon: "icons/timer.png"
        durationMs: 8000
        seq: perfTimer.resultSeq
    }
    Rectangle {          // backdrop so the door picture sits on its own over the menu
        x: 700; y: stage.lineTop + 2
        width: 520; height: stage.lineBottom - stage.lineTop - 4
        visible: doors.visible
        color: "#e6000000"
    }
    DoorCard {
        id: doors
        anchors.horizontalCenter: parent.horizontalCenter
        y: 180
        visible: car.anyDoorOpen
        fl: car.doorFL; fr: car.doorFR; rl: car.doorRL; rr: car.doorRR
        trunk: car.trunkOpen; hood: car.hoodOpen
        fontName: stage.fontName
    }

    // ── bottom row: odometer and range
    Text {
        x: 730 - width; y: 652
        text: {
            var raw = car.useMph ? car.odoMiles : car.odo
            var num = raw.replace(/[^0-9]/g, "")
            var unit = car.useMph ? "mi" : "km"
            return num === "" ? "" : ("000000" + num).slice(-6) + " " + unit
        }
        color: "#e9edf2"; font.pixelSize: 28; font.family: stage.fontName
    }
    Row {
        x: 1180; y: 652
        spacing: 10
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30; smooth: true
            source: car.fuelPercent <= 12 ? "icons/fuel_warn.png" : "icons/fuel.png"
        }
        Text {
            text: Units.withUnit(car.useMph ? car.rangeMiles : car.range, car.useMph)
            color: "#e9edf2"; font.pixelSize: 28; font.family: stage.fontName
        }
    }
    MediaTab {
        x: 960 - width / 2; y: 648
        nav: navData
    }
    // black curtain for the start-up / shut-down fade (above everything)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 1 - stage.reveal
        visible: opacity > 0.001
    }
    }
}
