// PREVIEW ONLY: stands in for the native ClusterVideo plugin so the desktop preview can
// show the dash with a navigation map in the band. Draws a generic day-mode map; the
// real picture comes from Android Auto on the car.
import QtQuick 2.14

Item {
    id: item
    property string host: ""
    property int port: 8766
    property rect sourceRect
    readonly property bool connected: host !== ""
    readonly property bool streaming: host !== ""
    property int framesDecoded: 0
    property bool paused: false              // tests: stop "frames" like a still Android Auto map
    Timer { interval: 100; repeat: true; running: item.host !== "" && !item.paused; onTriggered: item.framesDecoded++ }

    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            var w = width, h = height
            ctx.fillStyle = "#e6e8eb"; ctx.fillRect(0, 0, w, h)
            // water and parkland
            ctx.fillStyle = "#a9d0e0"
            ctx.beginPath(); ctx.moveTo(0, h * 0.05); ctx.quadraticCurveTo(w * 0.25, h * 0.18, w * 0.18, h * 0.42)
            ctx.lineTo(0, h * 0.5); ctx.closePath(); ctx.fill()
            ctx.fillStyle = "#cfe5c8"
            ctx.fillRect(w * 0.62, h * 0.12, w * 0.2, h * 0.22)
            ctx.fillRect(w * 0.08, h * 0.66, w * 0.16, h * 0.2)
            // road network
            function road(pts, wd, col) {
                ctx.strokeStyle = col; ctx.lineWidth = wd; ctx.lineCap = "round"; ctx.lineJoin = "round"
                ctx.beginPath(); ctx.moveTo(pts[0], pts[1])
                for (var i = 2; i < pts.length; i += 2) ctx.lineTo(pts[i], pts[i + 1])
                ctx.stroke()
            }
            var minor = [[0, h*0.62, w, h*0.55], [w*0.3, 0, w*0.36, h], [w*0.78, 0, w*0.7, h],
                         [0, h*0.85, w, h*0.92], [w*0.1, h*0.3, w*0.95, h*0.2]]
            for (var m = 0; m < minor.length; m++) { road(minor[m], 16, "#c9ccd1"); road(minor[m], 11, "#ffffff") }
            var main = [0, h*0.38, w*0.45, h*0.47, w, h*0.4]
            road(main, 26, "#e0b84a"); road(main, 20, "#f8d66a")
            // route ahead (blue), from the car up and right onto the main road
            var route = [w*0.5, h, w*0.5, h*0.62, w*0.53, h*0.47, w*0.9, h*0.42]
            road(route, 22, "#1a5fd0"); road(route, 15, "#4a8df0")
            // labels
            ctx.fillStyle = "#5f6670"; ctx.font = "22px sans-serif"
            ctx.fillText("Military Rd", w * 0.6, h * 0.36)
            ctx.fillText("Spit Rd", w * 0.22, h * 0.6)
            // position arrow
            var cx = w * 0.5, cy = h * 0.8
            ctx.fillStyle = "#ffffff"; ctx.beginPath(); ctx.arc(cx, cy, 24, 0, 2 * Math.PI); ctx.fill()
            ctx.fillStyle = "#1a73e8"
            ctx.beginPath(); ctx.moveTo(cx, cy - 18); ctx.lineTo(cx + 14, cy + 14); ctx.lineTo(cx, cy + 6)
            ctx.lineTo(cx - 14, cy + 14); ctx.closePath(); ctx.fill()
        }
    }
}
