// Gauge in the style of the 2018+ Range Rover virtual instrument panel: beaded outer
// ring, long/short ticks, alternating bright/dim numerals, thin inner ring, white
// needle, optional red-zone bracket, and a segmented mini gauge in the bottom gap.
// The static face is one Canvas painted once; only the needle (a Rectangle) moves.
import QtQuick 2.14
import "."

Item {
    id: dial

    property real value: 0
    property real maxValue: 280
    property real majorStep: 20        // tick + numeral spacing
    property int minorPerMajor: 2
    property real labelDivisor: 1
    property bool alternateDim: true   // every other numeral small and grey (speedo)
    property real redFrom: -1          // tach red zone
    property string scaleLabel: ""     // e.g. "km/h" or "rpm x 1000" under the top numeral
    property real size: 600

    // bottom-gap mini gauge
    property real gapFrac: 0
    property bool gapWarn: false
    property string gapIcon: ""
    property color gapLowColor: "#e0453a"   // first segment colour (fuel: red, coolant: blue)
    property color gapHighColor: "#e0453a"  // last segment colour (coolant hot)

    default property alias content: centre.data

    readonly property real startDeg: 125     // canvas degrees, 0 = 3 o'clock, clockwise
    readonly property real sweepDeg: 290
    readonly property real r: size / 2
    readonly property real frac: Math.max(0, Math.min(1, value / maxValue))

    width: size
    height: size

    function rad(d) { return d * Math.PI / 180 }

    // dark face with a faint centre lift
    Rectangle {
        anchors.centerIn: parent
        width: dial.size * 0.94; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#16191d" }
            GradientStop { position: 0.55; color: "#0a0b0d" }
            GradientStop { position: 1.0; color: "#050506" }
        }
    }

    // the face is painted once; repaint when the dash font finishes loading
    Connections {
        target: Theme
        onFontChanged: face.requestPaint()
    }

    Canvas {
        id: face
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = dial.r, cy = dial.r, R = dial.r

            // beaded bezel: two staggered rows of small bright beads between thin rings
            ctx.strokeStyle = "#8d949c"
            ctx.lineWidth = 1.2
            ctx.beginPath(); ctx.arc(cx, cy, R * 0.997, 0, 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.arc(cx, cy, R * 0.928, 0, 2 * Math.PI); ctx.stroke()
            var beads = 120
            for (var row = 0; row < 2; row++) {
                var br = R * (row === 0 ? 0.968 : 0.943)
                for (var b = 0; b < beads; b++) {
                    var ba = (b + row * 0.5) * 2 * Math.PI / beads
                    var bx = cx + br * Math.cos(ba), by = cy + br * Math.sin(ba)
                    var g = ctx.createRadialGradient(bx - 1.5, by - 1.5, 0, bx, by, R * (row === 0 ? 0.021 : 0.014))
                    g.addColorStop(0, "#ffffff")
                    g.addColorStop(0.6, "#c8cdd3")
                    g.addColorStop(1, "#4d535a")
                    ctx.fillStyle = g
                    ctx.globalAlpha = row === 0 ? 1.0 : 0.55
                    ctx.beginPath(); ctx.arc(bx, by, R * (row === 0 ? 0.019 : 0.012), 0, 2 * Math.PI); ctx.fill()
                }
            }

            ctx.globalAlpha = 1.0
            // ticks and numerals
            var steps = Math.round(dial.maxValue / dial.majorStep) * dial.minorPerMajor
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            for (var i = 0; i <= steps; i++) {
                var v = i * dial.majorStep / dial.minorPerMajor
                var a = dial.rad(dial.startDeg + dial.sweepDeg * v / dial.maxValue)
                var major = (i % dial.minorPerMajor) === 0
                var red = dial.redFrom >= 0 && v >= dial.redFrom
                var rOut = R * 0.915
                var rIn = R * (major ? 0.835 : 0.88)
                ctx.strokeStyle = red ? "#ff3b30" : "#e9edf2"
                ctx.lineWidth = major ? R * 0.016 : R * 0.008
                ctx.beginPath()
                ctx.moveTo(cx + rIn * Math.cos(a), cy + rIn * Math.sin(a))
                ctx.lineTo(cx + rOut * Math.cos(a), cy + rOut * Math.sin(a))
                ctx.stroke()
                if (major) {
                    var n = Math.round(v / dial.majorStep)
                    var dim = dial.alternateDim && (n % 2 === 0)
                    var rl = R * 0.745
                    ctx.font = Math.round(R * (dim ? 0.075 : 0.105)) + "px '" + Theme.font + "'"
                    ctx.fillStyle = red ? "#ff4a3d" : (dim ? "#8f979f" : "#f4f6f8")
                    ctx.fillText(Math.round(v / dial.labelDivisor), cx + rl * Math.cos(a), cy + rl * Math.sin(a))
                }
            }

            // red-zone bracket hugging the outside of the ticks (tach)
            if (dial.redFrom >= 0) {
                var z0 = dial.rad(dial.startDeg + dial.sweepDeg * dial.redFrom / dial.maxValue)
                var z1 = dial.rad(dial.startDeg + dial.sweepDeg)
                ctx.strokeStyle = "#e0251b"
                ctx.lineWidth = R * 0.010
                ctx.beginPath(); ctx.arc(cx, cy, R * 0.925, z0, z1); ctx.stroke()
                var caps = [z0, z1]
                for (var k = 0; k < 2; k++) {
                    ctx.beginPath()
                    ctx.moveTo(cx + R * 0.925 * Math.cos(caps[k]), cy + R * 0.925 * Math.sin(caps[k]))
                    ctx.lineTo(cx + R * 0.86 * Math.cos(caps[k]), cy + R * 0.86 * Math.sin(caps[k]))
                    ctx.stroke()
                }
            }

            // thin inner ring
            ctx.strokeStyle = "#d9dde2"
            ctx.lineWidth = R * 0.007
            ctx.beginPath(); ctx.arc(cx, cy, R * 0.555, 0, 2 * Math.PI); ctx.stroke()
        }
    }

    // bottom-gap mini gauge: segments across the gap, filling left to right
    Canvas {
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        property real f: dial.gapFrac
        property bool w: dial.gapWarn
        onFChanged: requestPaint()
        onWChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var R = dial.r
            var n = 6
            var gap = 360 - dial.sweepDeg
            var left = dial.startDeg - 6            // bottom-left end of the gap
            var span = gap - 12
            ctx.lineWidth = R * 0.03
            for (var i = 0; i < n; i++) {
                var hi = dial.rad(left - span * i / n - 1.5)
                var lo = dial.rad(left - span * (i + 1) / n + 1.5)
                var lit = (i + 0.5) / n <= f
                var c
                if (i === 0) c = dial.gapLowColor
                else if (i === n - 1 && dial.gapHighColor !== dial.gapLowColor) c = dial.gapHighColor
                else c = "#e9edf2"
                if (dial.w && lit) c = "#ff3b30"
                ctx.strokeStyle = lit || i === 0 || (i === n - 1 && dial.gapHighColor !== dial.gapLowColor) ? c : "#2a2e33"
                ctx.globalAlpha = lit ? 1.0 : 0.45
                ctx.beginPath()
                ctx.arc(dial.r, dial.r, R * 0.86, lo, hi, false)
                ctx.stroke()
            }
            ctx.globalAlpha = 1.0
        }
    }
    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.size * 0.86
        width: dial.size * 0.045; height: width
        visible: dial.gapIcon !== ""
        smooth: true
        source: dial.gapIcon === "" ? "" : "icons/" + dial.gapIcon + (dial.gapWarn ? "_warn" : "") + ".png"
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.size * 0.165
        visible: dial.scaleLabel !== ""
        text: dial.scaleLabel
        color: "#aeb5bd"
        font.pixelSize: dial.size * 0.028
        font.family: Theme.font
    }

    // needle: thin white bar from just outside the inner ring to the tick ring
    Item {
        anchors.fill: parent
        rotation: dial.startDeg + dial.sweepDeg * dial.frac + 90   // Rectangle points up at 0
        Rectangle {
            width: dial.size * 0.010
            height: dial.r * (0.915 - 0.57)
            radius: width / 2
            x: dial.r - width / 2
            y: dial.r - dial.r * 0.915
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffffff" }
                GradientStop { position: 1.0; color: "#c9ced4" }
            }
        }
    }

    Item {
        id: centre
        anchors.centerIn: parent
        width: dial.size * 0.50
        height: width
    }
}
