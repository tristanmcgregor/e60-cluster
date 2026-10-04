// Full-screen map mode: the Android Auto map fills the panel and the dials give way to
// compact readouts at the sides, Range Rover style. Edge fades keep the readouts and the
// status row legible over any map colours.
import QtQuick 2.14
import "."

Item {
    id: hud

    property var car
    property int speed: 0
    property string speedUnit: "km/h"
    property int limit: 0                  // in the display unit; 0 = none
    property bool overLimit: false
    property string fontName: Theme.font

    width: 1920
    height: 720

    // edge fades
    Rectangle {
        width: parent.width; height: 170
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#e6000000" }
            GradientStop { position: 1.0; color: "#00000000" }
        }
    }
    Rectangle {
        y: parent.height - 150; width: parent.width; height: 150
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#e6000000" }
        }
    }
    Rectangle {
        width: 520; height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#f2000000" }
            GradientStop { position: 0.55; color: "#b3000000" }
            GradientStop { position: 1.0; color: "#00000000" }
        }
    }
    Rectangle {
        x: parent.width - 520; width: 520; height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 0.45; color: "#b3000000" }
            GradientStop { position: 1.0; color: "#f2000000" }
        }
    }

    // left: speed and limit
    Column {
        x: 120; anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            text: hud.speed
            color: hud.overLimit ? Theme.critical : Theme.ink
            font.pixelSize: 132; font.family: hud.fontName
        }
        Row {
            spacing: 18
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hud.speedUnit
                color: Theme.inkSoft; font.pixelSize: 26; font.family: hud.fontName
            }
            LimitSign { anchors.verticalCenter: parent.verticalCenter; limit: hud.limit; over: hud.overLimit }
        }
    }

    // right: gear, revs and a slim rev bar with the (warm-up) red zone
    Column {
        anchors.right: parent.right; anchors.rightMargin: 120
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Text {
            anchors.right: parent.right
            text: hud.car.gearShow && hud.car.gear !== "" ? hud.car.gear : "P"
            color: hud.car.gear === "R" ? Theme.critical : Theme.ink
            font.pixelSize: 112; font.family: hud.fontName
        }
        Text {
            anchors.right: parent.right
            text: hud.car.rpm + " rpm"
            color: hud.car.rpm >= hud.car.shiftRpm ? Theme.critical : Theme.inkSoft
            font.pixelSize: 26; font.family: hud.fontName
        }
        Item {
            anchors.right: parent.right
            width: 260; height: 8
            readonly property real maxRpm: 8000
            Rectangle { anchors.fill: parent; radius: 4; color: "#33ffffff" }
            Rectangle {            // red zone from the current redline
                x: parent.width * hud.car.redlineRpm / parent.maxRpm
                width: parent.width - x; height: parent.height; radius: 4
                color: "#80e0251b"
            }
            Rectangle {
                width: parent.width * Math.min(1, hud.car.rpm / parent.maxRpm)
                height: parent.height; radius: 4
                color: hud.car.rpm >= hud.car.shiftRpm ? Theme.critical : Theme.ink
            }
        }
    }
}
