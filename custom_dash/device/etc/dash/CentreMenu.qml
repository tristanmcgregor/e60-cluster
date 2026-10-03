// Centre-band menu: a title strip with page dots and one page at a time.
// Left/right or a BC press changes page; Navigation is chosen automatically when a
// route starts. The live map itself is drawn by Dashboard.qml behind the dials while
// this menu is on the Navigation page.
import QtQuick 2.14
import "."

Item {
    id: menu

    property var car
    property var nav
    property bool mph: false
    property bool mapStreaming: false     // set by Dashboard when the live map has a picture
    property bool dimmed: false           // a check-control message is showing over the page

    readonly property var titles: ["TRIP", "VEHICLE", "NAVIGATION", "INFO"]
    property int page: 0
    readonly property bool onNavPage: page === 2

    width: 520
    height: 480

    function step(delta) { page = (page + delta + titles.length) % titles.length }

    // tell the MCU which page is up (stock EventHub.MenuId per page; see Car.menuId)
    readonly property var menuIds: [257, 519, 769, 1030]
    onPageChanged: if (car) car.menuId = menuIds[page]

    Connections {
        target: menu.car
        // Qt 5.14: handler-property form (function-style handlers need 5.15)
        onButton: {
            switch (code) {
            case 21: menu.step(-1); break           // left
            case 22: case 26: menu.step(1); break   // right, BC single press
            }
        }
    }
    Connections {
        target: menu.nav
        onActiveChanged: if (menu.nav.active) menu.page = 2
    }

    // title strip
    Item {
        id: header
        width: parent.width
        height: 56
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -6
            text: menu.titles[menu.page]
            color: Theme.text
            font.pixelSize: Theme.tLabel + 3
            font.family: Theme.font
            font.letterSpacing: 3
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 10
            Repeater {
                model: menu.titles.length
                Rectangle {
                    width: index === menu.page ? 22 : 8
                    height: 4; radius: 2
                    color: index === menu.page ? Theme.text : Theme.textFaint
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }
        }
    }

    Item {
        id: body
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: parent.height - header.height - 12
        opacity: menu.dimmed ? 0.08 : 1
        Behavior on opacity { NumberAnimation { duration: 220 } }

        TripCard {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: menu.page === 0
            car: menu.car
        }
        VehiclePage {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: menu.page === 1
            car: menu.car
        }
        Item {
            anchors.fill: parent
            visible: menu.page === 2
            NavCard {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: menu.nav.active && !menu.mapStreaming
                nav: menu.nav
                useMph: menu.mph
                fontName: Theme.font
            }
            Text {
                anchors.centerIn: parent
                visible: !menu.nav.active
                width: parent.width - 60
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: menu.nav.connected ? "No route. Start navigation in Android Auto."
                                         : "Android Auto is not connected."
                color: Theme.textDim
                font.pixelSize: Theme.tBody
                font.family: Theme.font
            }
        }
        InfoPage {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: menu.page === 3
            car: menu.car
            nav: menu.nav
        }
    }
}
