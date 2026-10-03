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

    // text
    readonly property color text: "#eef2f7"
    readonly property color textDim: "#8b96a7"
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
