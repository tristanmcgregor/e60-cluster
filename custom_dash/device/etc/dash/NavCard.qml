// Turn-by-turn card for the centre panel: arrow, distance to the turn, street, then ETA.
import QtQuick 2.14

Item {
    id: card

    property var nav                 // Nav.qml instance
    property bool useMph: false
    property string fontName: ""

    width: 440
    height: 400

    // AA instrument-cluster NavigationType -> icon in icons/nav_*.png and a label
    function iconFor(m) {
        switch (m) {
        case 1: case 2: case 36: return "straight"
        case 3: return "fork_left"
        case 4: return "fork_right"
        case 5: return "turn_slight_left"
        case 6: return "turn_slight_right"
        case 7: return "turn_left"
        case 8: return "turn_right"
        case 9: return "turn_sharp_left"
        case 10: return "turn_sharp_right"
        case 11: case 19: return "u_turn_left"
        case 12: case 20: return "u_turn_right"
        case 13: case 15: case 17: case 21: case 23: return "ramp_left"
        case 14: case 16: case 18: case 22: case 24: return "ramp_right"
        case 25: return "fork_left"
        case 26: return "fork_right"
        case 27: case 28: case 29: return "merge"
        case 30: case 31: case 32: case 33: return "roundabout_left"     // clockwise (left-hand traffic)
        case 34: case 35: return "roundabout_right"
        case 37: case 38: return "directions_boat"
        case 39: case 40: case 41: case 42: return "flag"
        default: return "navigation"
        }
    }
    function labelFor(m) {
        var labels = {
            1: "Head", 2: "Continue", 3: "Keep left", 4: "Keep right",
            5: "Slight left", 6: "Slight right", 7: "Turn left", 8: "Turn right",
            9: "Sharp left", 10: "Sharp right", 11: "U-turn", 12: "U-turn",
            13: "Take the ramp", 14: "Take the ramp", 15: "Take the ramp", 16: "Take the ramp",
            17: "Take the ramp", 18: "Take the ramp", 19: "U-turn", 20: "U-turn",
            21: "Take the exit", 22: "Take the exit", 23: "Take the exit", 24: "Take the exit",
            25: "Keep left", 26: "Keep right", 27: "Merge", 28: "Merge", 29: "Merge",
            30: "Enter the roundabout", 31: "Exit the roundabout", 36: "Continue straight",
            37: "Take the ferry", 38: "Take the train", 39: "Arrive", 40: "Arrive",
            41: "Arrive on the left", 42: "Arrive on the right"
        }
        if (m >= 32 && m <= 35 && card.nav.roundaboutExit > 0)
            return "Roundabout, exit " + card.nav.roundaboutExit
        if (m >= 32 && m <= 35) return "At the roundabout"
        return labels[m] || card.nav.action || "Continue"
    }
    function distanceText(meters) {
        if (meters < 0) return ""
        if (card.useMph) {
            var ft = meters * 3.28084
            if (ft < 1000) return (Math.round(ft / 50) * 50) + " ft"
            return (meters / 1609.34).toFixed(meters < 16093 ? 1 : 0) + " mi"
        }
        if (meters < 100) return (Math.round(meters / 5) * 5) + " m"
        if (meters < 1000) return (Math.round(meters / 10) * 10) + " m"
        return (meters / 1000).toFixed(meters < 10000 ? 1 : 0) + " km"
    }
    function durationText(s) {
        if (s < 0) return ""
        var min = Math.round(s / 60)
        return min < 60 ? min + " min" : Math.floor(min / 60) + " h " + (min % 60) + " min"
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 150; height: 150
            smooth: true
            source: "icons/nav_" + card.iconFor(card.nav.maneuver) + ".png"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: card.distanceText(card.nav.distanceM)
            color: "#ffffff"
            font.pixelSize: 64
            font.family: card.fontName
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: card.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: card.labelFor(card.nav.maneuver)
            color: "#c9d0da"
            font.pixelSize: 26
            font.family: card.fontName
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: card.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: card.nav.road !== ""
            text: card.nav.road
            color: "#ffffff"
            font.pixelSize: 32
            font.family: card.fontName
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 280; height: 2; color: "#3a4452" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: [card.nav.eta !== "" ? card.nav.eta : "",
                   card.distanceText(card.nav.totalDistanceM),
                   card.durationText(card.nav.totalTimeS)].filter(function(s) { return s !== "" }).join("  ·  ")
            color: "#9aa4b5"
            font.pixelSize: 24
            font.family: card.fontName
        }
    }
}
