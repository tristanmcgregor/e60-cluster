// Turn-by-turn data from Android Auto, pushed by our Open Headunit build (ClusterLink.kt)
// over the head unit's Wi-Fi hotspot. /etc/init.d/S60wifi writes the hotspot gateway
// (= the head unit) to /tmp/nav_gateway; we connect to ws://<gateway>:8765/nav.
//
// Field meanings follow Open Headunit's NavigationUpdateIntent. maneuver is AA's
// instrument-cluster NavigationType (navigation.proto); -1 means "not provided".
import QtQuick 2.14
import QtWebSockets 1.1

Item {
    id: nav

    property string gatewayFile: "file:///tmp/nav_gateway"
    property string gateway: ""

    readonly property bool connected: ws.status === WebSocket.Open
    property bool active: false
    property int maneuver: 0
    property string action: ""
    property string road: ""
    property int distanceM: -1
    property int timeS: -1
    property int roundaboutExit: -1
    property int totalDistanceM: -1
    property int totalTimeS: -1
    property string eta: ""

    // now playing / phone call from Android Auto (ClusterLink "media" and "call" messages)
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool mediaPlaying: false
    property string mediaArt: ""       // album art as a data: URL (head unit "mediaart" message)
    property int mediaDuration: 0      // seconds, 0 = unknown
    property int mediaPosition: 0      // seconds, as of mediaPositionAt
    property real mediaPositionAt: 0   // Date.now() when mediaPosition was received
    property bool callActive: false
    property int callState: 0          // AA PhoneStatus: 1 in call, 2 on hold, 3 hanging up, 4 incoming
    property string callerName: ""
    property string callerNumber: ""
    property int callSeconds: 0

    function readGateway() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            var gw = (xhr.responseText || "").trim()
            if (/^[0-9.]+$/.test(gw) && gw !== nav.gateway) {
                console.log("[nav] head unit at " + gw)
                nav.gateway = gw
            }
        }
        xhr.open("GET", gatewayFile)
        xhr.send()
    }

    // display settings from the phone settings page (head unit CarSettings)
    signal settingsReceived(var settings)
    // limit of the road the car is on, km/h (head unit SpeedLimits); 0 = unknown
    property int speedLimitKph: 0
    property bool speedLimitSchool: false   // a school-zone limit is in force right now
    // camera ahead (head unit SpeedLimits): kind "speed" | "redlight" | "average"; distance -1 = none
    property string cameraKind: ""
    property int cameraDistM: -1
    property int cameraKph: 0
    property real cameraAt: 0               // Date.now() of the last camera message
    // GPS speed from the head unit, km/h; -1 = none yet (see GpsCheck)
    property real gpsKph: -1
    property int gpsAcc: 0
    property real gpsAt: 0
    signal gpsFix()
    // size of the map the phone draws in the cluster video (head unit "clustermap" message)
    property int mapWidth: 800
    property int mapHeight: 480
    property int videoWidth: 0      // whole video; 0 = not reported (ClusterMap works it out)
    property int videoHeight: 0

    function apply(msg) {
        var d
        try { d = JSON.parse(msg) } catch (e) { return }
        if (d.type === "settings") {
            settingsReceived(d)
            return
        }
        if (d.type === "clustermap") {
            mapWidth = d.width || 800
            mapHeight = d.height || 480
            videoWidth = d.videoWidth || 0
            videoHeight = d.videoHeight || 0
            return
        }
        if (d.type === "limit") {
            speedLimitKph = d.kph || 0
            speedLimitSchool = d.school === true
            return
        }
        if (d.type === "camera") {
            cameraAt = Date.now()
            if ((d.distM || 0) < 0) { cameraDistM = -1; return }
            cameraKind = d.kind || "speed"
            cameraKph = d.kph || 0
            cameraDistM = d.distM
            return
        }
        if (d.type === "gps") {
            gpsKph = d.kph
            gpsAcc = d.acc || 0
            gpsAt = Date.now()
            gpsFix()
            return
        }
        if (d.type === "media") {
            mediaTitle = d.title || ""
            mediaArtist = d.artist || ""
            mediaPlaying = d.playing === true
            mediaDuration = d.duration || 0
            mediaPosition = d.position || 0
            mediaPositionAt = Date.now()
            if (d.art !== undefined) mediaArt = d.art
            return
        }
        if (d.type === "mediaart") {
            mediaArt = d.art || ""
            return
        }
        if (d.type === "call") {
            callActive = d.active === true
            callState = d.state || 0
            callerName = d.name || ""
            callerNumber = d.number || ""
            callSeconds = d.seconds || 0
            return
        }
        active = d.active === true
        maneuver = d.maneuver !== undefined ? d.maneuver : 0
        action = d.action || ""
        road = d.road || ""
        distanceM = d.distance_m !== undefined ? d.distance_m : -1
        timeS = d.time_s !== undefined ? d.time_s : -1
        roundaboutExit = d.roundabout_exit !== undefined ? d.roundabout_exit : -1
        totalDistanceM = d.total_distance_m !== undefined ? d.total_distance_m : -1
        totalTimeS = d.total_time_s !== undefined ? d.total_time_s : -1
        eta = d.eta || ""
    }

    WebSocket {
        id: ws
        url: nav.gateway !== "" ? "ws://" + nav.gateway + ":8765/nav" : ""
        active: false
        onTextMessageReceived: nav.apply(message)
        onStatusChanged: {
            if (status === WebSocket.Open) console.log("[nav] connected")
            if (status === WebSocket.Error || status === WebSocket.Closed) {
                nav.active = false
                nav.callActive = false
                nav.mediaTitle = ""
                nav.cameraDistM = -1
                active = false              // the retry timer reopens it
            }
        }
    }

    // a camera countdown goes stale if the head unit stops sending (GPS lost, link dropped)
    Timer {
        interval: 1000; repeat: true; running: nav.cameraDistM >= 0
        onTriggered: if (Date.now() - nav.cameraAt > 5000) nav.cameraDistM = -1
    }

    // Find the head unit, then (re)connect every few seconds while not connected.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (nav.connected) return
            nav.readGateway()
            if (nav.gateway !== "" && ws.status !== WebSocket.Connecting) {
                ws.active = false
                ws.active = true
            }
        }
    }
}
