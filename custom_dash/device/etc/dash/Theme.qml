// Shared palette, type and metrics for every dash component.
pragma Singleton
import QtQuick 2.14

QtObject {
    // surfaces
    readonly property color bgTop: "#0b0f15"
    readonly property color bgBottom: "#030406"
    readonly property color panel: "#0f141b"
    readonly property color hairline: "#1f2731"
    readonly property color track: "#1a212b"

    // "Classic BMW" theme (phone setting "theme"): amber markings like the E60's own instrument
    // lighting, on all the time. Set by Car.applySettings; dashClassic: desktop preview override.
    property bool classic: typeof dashClassic !== "undefined" ? dashClassic : false

    // text
    readonly property color text: classic ? "#efa457" : "#eef2f7"
    readonly property color textDim: classic ? "#94693f" : "#8b96a7"

    // dial and status-row ink (numerals, ticks, rings, needles, big digits)
    readonly property color ink: classic ? "#f2a858" : "#f4f6f8"
    readonly property color inkTick: classic ? "#e09a50" : "#e9edf2"
    readonly property color inkSoft: classic ? "#a8743e" : "#aeb5bd"
    readonly property color inkDim: classic ? "#7d5833" : "#8f979f"
    readonly property color ring: classic ? "#b4793a" : "#d9dde2"
    readonly property color needle: classic ? "#ff7a2e" : "#ffffff"
    readonly property color beadHi: classic ? "#f0b06a" : "#ffffff"
    readonly property color beadMid: classic ? "#b07840" : "#c8cdd3"
    readonly property color beadLo: classic ? "#3c2a18" : "#4d535a"
    readonly property color bezelLine: classic ? "#7a5a38" : "#8d949c"
    readonly property color textFaint: "#4f5968"

    // accents
    readonly property color speedAccent: "#bcd7ff"   // speedometer arc
    readonly property color sportAccent: "#ff3b30"   // sport layout: tach ring and needle
    readonly property color tachAccent: "#f2a33a"    // tachometer arc
    readonly property color info: "#4aa3ff"
    readonly property color ok: "#35d07f"
    readonly property color warn: "#ffb340"
    readonly property color critical: "#ff4d4d"

    // Titillium Web (SIL Open Font License) ships in fonts/; BMW Type Global (on the unit) is
    // the fallback. dashFont: optional override from the desktop preview.
    property FontLoader titillium: FontLoader { source: "fonts/TitilliumWeb-Regular.ttf" }
    property FontLoader titilliumLight: FontLoader { source: "fonts/TitilliumWeb-Light.ttf" }
    readonly property string font: typeof dashFont !== "undefined" ? dashFont
        : (titillium.status === FontLoader.Ready ? titillium.name : "BMW Type Global")

    // type scale (px)
    readonly property int tHero: 132     // digital speed / gear
    readonly property int tLarge: 54
    readonly property int tMedium: 34
    readonly property int tBody: 24
    readonly property int tLabel: 17     // uppercase labels, letter-spaced
}
