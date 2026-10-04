// Centre menu page: software versions, link status and the last button code
// (to confirm the steering-wheel mapping on the car).
import QtQuick 2.14
import "."

Column {
    id: page

    property var car
    property var nav
    property var updates      // UpdateWatch

    width: 440
    spacing: 6

    function orDash(s) { return s && s !== "" ? s : "--" }

    // the RELEASE file beside the dash files actually loaded (OTA folder or the USB install)
    property string release: ""
    Component.onCompleted: {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            page.release = (xhr.responseText || "").trim()
            console.log("[dash] running release " + (page.release || "unknown"))
        }
        xhr.open("GET", Qt.resolvedUrl("RELEASE"))
        xhr.send()
    }

    Stat {
        fit: true
        width: 440; label: "DASH"
        value: (parseInt(page.release) > 0 ? "Release " + parseInt(page.release) : "Development build")
               + (page.updates && page.updates.pending > 0 ? "  ·  " + page.updates.pending + " loads next start" : "")
    }
    Stat { fit: true; width: 440; label: "EVENTHUB / CAN"; value: page.orDash(page.car.hubVersion) + "  ·  " + page.orDash(page.car.mcuVersion) }
    Stat {
        fit: true
        width: 440
        label: "HEAD UNIT LINK"
        value: page.nav.gateway === "" ? "Not on the hotspot"
             : (page.nav.connected ? "Connected to " + page.nav.gateway : "Hotspot " + page.nav.gateway + ", app not answering")
    }
    Stat {
        fit: true
        width: 440
        label: "SETTINGS PAGE"
        value: page.nav.gateway === "" ? "--" : "http://" + page.nav.gateway + ":8765/settings"
    }
    Stat { fit: true; width: 440; label: "LAST BUTTON CODE"; value: page.car.lastButton > 0 ? String(page.car.lastButton) : "--" }
}
