// Top-down E60 with open doors / boot / bonnet highlighted. The body is one Canvas painted
// once; doors swing out from their front hinges and the lids fold back, all animated.
import QtQuick 2.14

Item {
    id: card

    property bool fl: false
    property bool fr: false
    property bool rl: false
    property bool rr: false
    property bool trunk: false
    property bool hood: false
    property string fontName: ""

    readonly property color openColor: "#ff4a3d"
    readonly property color shutColor: "#55606f"
    readonly property color lineColor: "#8c96a6"

    readonly property int doorCount: (fl ? 1 : 0) + (fr ? 1 : 0) + (rl ? 1 : 0) + (rr ? 1 : 0)

    width: 320
    height: 384
    // grows in slightly as Dashboard fades the card in
    scale: 0.9 + 0.1 * opacity

    // slow breathing glow on whatever is open
    property real pulse: 1
    SequentialAnimation on pulse {
        running: card.visible
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.45; to: 1; duration: 900; easing.type: Easing.InOutSine }
    }

    Item {
        id: car
        width: 124; height: 268
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        scale: 1.2
        transformOrigin: Item.Top

        Canvas {
            id: shell
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            onPaint: {
                var c = getContext("2d"), w = width, h = height
                c.reset()
                // body: rounded nose, slight waist at the doors, squarer tail
                c.beginPath()
                c.moveTo(w / 2, 2)
                c.bezierCurveTo(w - 18, 2, w - 6, 10, w - 5, 40)
                c.lineTo(w - 3, 90)
                c.lineTo(w - 4, 210)
                c.lineTo(w - 6, 248)
                c.bezierCurveTo(w - 8, 262, w - 24, 266, w / 2, 266)
                c.bezierCurveTo(24, 266, 8, 262, 6, 248)
                c.lineTo(4, 210)
                c.lineTo(3, 90)
                c.lineTo(5, 40)
                c.bezierCurveTo(6, 10, 18, 2, w / 2, 2)
                c.closePath()
                var g = c.createLinearGradient(0, 0, w, 0)
                g.addColorStop(0, "#151b23"); g.addColorStop(0.5, "#252e3a"); g.addColorStop(1, "#151b23")
                c.fillStyle = g
                c.fill()
                c.lineWidth = 2.5
                c.strokeStyle = card.lineColor
                c.stroke()

                // glass: windscreen, side windows, rear window
                c.fillStyle = "#2e3947"
                c.strokeStyle = "#6b7686"
                c.lineWidth = 1.5
                c.beginPath()            // windscreen
                c.moveTo(20, 104); c.quadraticCurveTo(w / 2, 82, w - 20, 104)
                c.lineTo(w - 26, 130); c.quadraticCurveTo(w / 2, 122, 26, 130)
                c.closePath(); c.fill(); c.stroke()
                c.beginPath()            // rear window
                c.moveTo(26, 200); c.quadraticCurveTo(w / 2, 206, w - 26, 200)
                c.lineTo(w - 22, 220); c.quadraticCurveTo(w / 2, 230, 22, 220)
                c.closePath(); c.fill(); c.stroke()
                // roof
                c.fillStyle = "#1e2630"
                c.beginPath()
                c.moveTo(26, 132); c.quadraticCurveTo(w / 2, 125, w - 26, 132)
                c.lineTo(w - 26, 198); c.quadraticCurveTo(w / 2, 203, 26, 198)
                c.closePath(); c.fill()
                // side windows (thin strips along the roof)
                c.fillStyle = "#2e3947"
                c.fillRect(16, 112, 7, 92)
                c.fillRect(w - 23, 112, 7, 92)
                // mirrors
                c.fillStyle = card.lineColor
                c.beginPath(); c.moveTo(4, 98); c.lineTo(-8, 94); c.lineTo(-8, 102); c.lineTo(4, 106); c.closePath(); c.fill()
                c.beginPath(); c.moveTo(w - 4, 98); c.lineTo(w + 8, 94); c.lineTo(w + 8, 102); c.lineTo(w - 4, 106); c.closePath(); c.fill()
                // kidney grille hint
                c.fillStyle = "#6b7686"
                c.fillRect(w / 2 - 13, 5, 10, 3)
                c.fillRect(w / 2 + 3, 5, 10, 3)
            }
        }

        // door openings: red behind each door, seen once it swings away
        Repeater {
            model: [
                { left: true,  y: 96,  h: 58, open: card.fl },
                { left: false, y: 96,  h: 58, open: card.fr },
                { left: true,  y: 156, h: 50, open: card.rl },
                { left: false, y: 156, h: 50, open: card.rr }
            ]
            Rectangle {
                x: modelData.left ? 2 : car.width - 10
                y: modelData.y + 2
                width: 8; height: modelData.h - 4; radius: 3
                color: card.openColor
                opacity: modelData.open ? 0.35 + 0.35 * card.pulse : 0
                Behavior on opacity { enabled: !modelData.open; NumberAnimation { duration: 250 } }
            }
        }

        // bonnet: hinged at the windscreen, folds forward when open
        Rectangle {
            id: bonnet
            x: 14; y: 12; width: car.width - 28; height: 70
            radius: 18
            color: card.hood ? card.openColor : "transparent"
            opacity: card.hood ? 0.55 + 0.4 * card.pulse : 1
            border.width: 1.5
            border.color: card.hood ? card.openColor : "#3a4452"
            Behavior on color { ColorAnimation { duration: 250 } }
            transform: Scale {
                origin.y: bonnet.height
                yScale: card.hood ? 0.72 : 1
                Behavior on yScale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
            }
        }
        // boot lid: hinged at the rear window, folds back when open
        Rectangle {
            id: bootLid
            x: 16; y: 226; width: car.width - 32; height: 34
            radius: 12
            color: card.trunk ? card.openColor : "transparent"
            opacity: card.trunk ? 0.55 + 0.4 * card.pulse : 1
            border.width: 1.5
            border.color: card.trunk ? card.openColor : "#3a4452"
            Behavior on color { ColorAnimation { duration: 250 } }
            transform: Scale {
                origin.y: 0
                yScale: card.trunk ? 0.6 : 1
                Behavior on yScale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
            }
        }

        // doors: outer skins that swing out from the front hinge
        Repeater {
            model: [
                { left: true,  y: 96,  h: 58, open: card.fl },
                { left: false, y: 96,  h: 58, open: card.fr },
                { left: true,  y: 156, h: 50, open: card.rl },
                { left: false, y: 156, h: 50, open: card.rr }
            ]
            Rectangle {
                id: door
                readonly property bool open: modelData.open
                width: 8; height: modelData.h; radius: 3
                x: modelData.left ? -2 : car.width - 6
                y: modelData.y
                color: open ? card.openColor : card.shutColor
                Behavior on color { ColorAnimation { duration: 250 } }
                antialiasing: true
                transformOrigin: Item.Top
                rotation: open ? (modelData.left ? 42 : -42) : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: door.open ? 520 : 320
                        easing.type: door.open ? Easing.OutBack : Easing.InOutQuad
                        easing.overshoot: 1.6
                    }
                }
                // soft glow round an open door
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 10; height: parent.height + 10; radius: 8
                    color: "transparent"
                    border.width: 4
                    border.color: card.openColor
                    opacity: door.open ? 0.25 * card.pulse : 0
                    antialiasing: true
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: {
            var lids = (card.hood ? 1 : 0) + (card.trunk ? 1 : 0)
            if (card.doorCount === 0)
                return lids === 2 ? "BONNET & BOOT OPEN" : card.hood ? "BONNET OPEN" : "BOOT OPEN"
            var what = card.doorCount > 1 ? "DOORS"
                     : card.fr ? "DRIVER'S DOOR"        // right-hand drive
                     : card.fl ? "PASSENGER DOOR"
                     : "REAR DOOR"
            if (card.trunk) what += " & BOOT"
            else if (card.hood) what += " & BONNET"
            return what + " OPEN"
        }
        color: card.openColor
        font.pixelSize: 26
        font.family: card.fontName
        font.letterSpacing: 1
    }
}
