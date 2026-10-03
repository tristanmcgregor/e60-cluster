// Centre menu page: software versions, link status and the last button code
// (to confirm the steering-wheel mapping on the car).
import QtQuick 2.14
import "."

Column {
    id: page

    property var car
    property var nav

    width: 440
    spacing: 14

    function orDash(s) { return s && s !== "" ? s : "--" }

    Stat { width: 440; label: "DASH"; value: "Custom JLR-style dash" }
    Stat { width: 440; label: "EVENTHUB / CAN"; value: page.orDash(page.car.hubVersion) + "  ·  " + page.orDash(page.car.mcuVersion) }
    Stat {
        width: 440
        label: "HEAD UNIT LINK"
        value: page.nav.gateway === "" ? "Not on the hotspot"
             : (page.nav.connected ? "Connected to " + page.nav.gateway : "Hotspot " + page.nav.gateway + ", app not answering")
    }
    Stat {
        width: 440
        label: "SETTINGS (PHONE BROWSER ON THE CAR WI-FI)"
        value: page.nav.gateway === "" ? "--" : "http://" + page.nav.gateway + ":8765/settings"
    }
    Stat { width: 440; label: "LAST BUTTON CODE"; value: page.car.lastButton > 0 ? String(page.car.lastButton) : "--" }
}
