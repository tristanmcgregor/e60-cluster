// Check-control message (EventHub.warningId / warningDuration), shown as a slim strip
// in the lower part of the centre band: the message's own icon, then its text.
// warningId indexes the stock Launcher's message table (Notify.js), not the warning-light table.
import QtQuick 2.14
import "."
import "Notify.js" as Notify

Item {
    id: pop

    property int alarmId: 0
    property int durationMs: 0
    property int seq: 0
    property string iconBase: "qrc:/"
    property string fontName: Theme.font
    // set both to show something other than a check-control message (e.g. a service reminder)
    property string customText: ""
    property string customIcon: ""

    property bool forceCritical: false     // red strip for a custom message (CarWarnings)
    readonly property bool critical: forceCritical || (customText === "" && Notify.critical(alarmId))
    property bool shown: false

    width: 500
    height: 112
    visible: opacity > 0.01
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }

    // rise into place when shown
    transform: Translate { y: pop.shown ? 0 : 14; Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }

    onSeqChanged: {
        // like the stock UI: shown only while the MCU gives it a duration
        if ((alarmId <= 0 && customText === "") || durationMs <= 0) { shown = false; return }
        shown = true
        hide.interval = durationMs
        hide.restart()
    }
    Timer { id: hide; onTriggered: pop.shown = false }

    Rectangle {
        anchors.fill: parent
        radius: 14
        border.width: 1
        border.color: pop.critical ? "#7a2a26" : "#3a4048"
        gradient: Gradient {
            GradientStop { position: 0.0; color: pop.critical ? "#ff1f1112" : "#ff181b20" }
            GradientStop { position: 1.0; color: "#ff0b0c0e" }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 24
        spacing: 22
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true
            // a missing icon falls back to the generic one; tracked in a flag rather than by
            // assigning source, which would cut the binding and freeze the icon from then on
            property string wanted: pop.customIcon !== "" ? pop.customIcon : pop.iconBase + Notify.icon(pop.alarmId)
            property bool failed: false
            onWantedChanged: failed = false
            source: failed ? pop.iconBase + "images/notify/001.png" : wanted
            onStatusChanged: if (status === Image.Error && !failed) failed = true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: pop.width - 24 - 64 - 22 - 24
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: pop.customText !== "" ? pop.customText
                  : Notify.name(pop.alarmId).replace(/,\s*/g, ", ").replace(/\.\s*/g, ". ").trim()
            color: Theme.text
            font.pixelSize: 26
            font.family: pop.fontName
            lineHeight: 1.05
        }
    }
}
