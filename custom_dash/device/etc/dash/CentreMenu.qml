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
    property var fuel                     // FuelTracker, for the FUEL page
    property var updates                  // UpdateWatch, for the INFO page

    // Pages are referred to by name; the last one, DEVELOPER, is hidden (hold BC on INFO).
    readonly property var titles: ["TRIP", "FUEL", "VEHICLE", "NAVIGATION", "INFO", "DEVELOPER"]
    readonly property int pageCount: titles.length - 1
    property int page: 0
    readonly property string current: titles[page]
    readonly property bool onNavPage: current === "NAVIGATION"
    function show(name) { page = titles.indexOf(name) }

    // the phone settings' default-page numbers (kept stable as pages are added)
    readonly property var settingsPages: ["TRIP", "VEHICLE", "NAVIGATION", "INFO", "FUEL"]

    width: 520
    height: 480

    function step(delta) {
        userMoved = true
        var from = current === "DEVELOPER" ? titles.indexOf("INFO") : page
        page = (from + delta + pageCount) % pageCount
    }

    // tell the MCU which page is up (stock EventHub.MenuId per page; see Car.menuId)
    readonly property var menuIds: ({ TRIP: 257, FUEL: 258, VEHICLE: 519, NAVIGATION: 769, INFO: 1030, DEVELOPER: 1032 })
    onPageChanged: if (car) car.menuId = menuIds[current]

    Connections {
        target: menu.car
        // Qt 5.14: handler-property form (function-style handlers need 5.15)
        onButton: {
            switch (code) {
            case 21: menu.step(-1); break           // left
            case 22: case 26: menu.step(1); break   // right, BC single press
            case 26 + 128: if (menu.current === "INFO") menu.show("DEVELOPER"); break
            }
        }
    }
    // start on the page chosen in the phone settings (stored copy arrives at start-up)
    Connections {
        target: menu.car
        onSettingsApplied: if (!menu.userMoved) menu.show(menu.settingsPages[menu.car.defaultPage] || "TRIP")
    }
    property bool userMoved: false
    Connections {
        target: menu.nav
        onActiveChanged: if (menu.nav.active) menu.show("NAVIGATION")
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
                model: menu.pageCount
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
            visible: menu.current === "TRIP"
            car: menu.car
        }
        FuelPage {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: menu.current === "FUEL"
            car: menu.car
            fuel: menu.fuel
        }
        VehiclePage {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: menu.current === "VEHICLE"
            car: menu.car
        }
        Item {
            anchors.fill: parent
            visible: menu.onNavPage
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
            visible: menu.current === "INFO"
            car: menu.car
            nav: menu.nav
            updates: menu.updates
        }
        DevPage {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: menu.current === "DEVELOPER"
            car: menu.car
        }
    }
}
