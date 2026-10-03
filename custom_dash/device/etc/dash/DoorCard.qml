// Top-down car outline with open doors / boot / bonnet highlighted.
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
    readonly property color shutColor: "#4a5563"

    width: 260
    height: 300

    // body
    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: 110; height: 230
        radius: 30
        color: "#1b222b"
        border.width: 3
        border.color: "#8c96a6"
    }
    // bonnet / boot
    Rectangle {
        anchors.horizontalCenter: body.horizontalCenter
        anchors.top: body.top; anchors.topMargin: 6
        width: 84; height: 44; radius: 16
        color: card.hood ? card.openColor : card.shutColor
    }
    Rectangle {
        anchors.horizontalCenter: body.horizontalCenter
        anchors.bottom: body.bottom; anchors.bottomMargin: 6
        width: 84; height: 38; radius: 14
        color: card.trunk ? card.openColor : card.shutColor
    }
    // doors: swing outward when open
    Repeater {
        model: [
            { left: true,  y: 66,  open: card.fl },
            { left: false, y: 66,  open: card.fr },
            { left: true,  y: 130, open: card.rl },
            { left: false, y: 130, open: card.rr }
        ]
        Rectangle {
            width: 8; height: 56; radius: 3
            x: modelData.left ? body.x - 4 : body.x + body.width - 4
            y: body.y + modelData.y
            color: modelData.open ? card.openColor : card.shutColor
            transformOrigin: Item.Top
            rotation: modelData.open ? (modelData.left ? 35 : -35) : 0
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: card.hood && !(card.fl || card.fr || card.rl || card.rr || card.trunk) ? "BONNET OPEN"
            : card.trunk && !(card.fl || card.fr || card.rl || card.rr || card.hood) ? "BOOT OPEN"
            : "DOOR OPEN"
        color: card.openColor
        font.pixelSize: 26
        font.family: card.fontName
    }
}
