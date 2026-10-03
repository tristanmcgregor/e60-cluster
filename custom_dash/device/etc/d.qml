// Bootstrap loaded by the patched Launcher (its "qrc:/main.qml" literal is
// rewritten to "file:/etc/d.qml"). Keeps the custom dashboard isolated: if no
// dash version compiles and constructs, the stock JLY UI (still compiled into
// the Launcher at qrc:/main.qml) is loaded instead.
//
// Dash versions, newest first (see updater/PROTOCOL.md):
//   /etc/dashv/<active>/  over-the-air release named by /etc/dash_active
//   /etc/dashv/<prev>/    the release before it, named by /etc/dash_prev
//   /etc/dash/            the version installed from USB (its RELEASE file gives its number)
// An over-the-air release is only preferred when it is newer than the USB one,
// so a later USB install is never hidden behind an older download.
import QtQuick 2.14

QtObject {
    id: boot

    property var window: null
    property string root: "/etc"      // overridden only by the desktop test

    function loadStock(reason) {
        console.warn("[d.qml] custom dash unavailable (" + reason + "), loading stock UI")
        var c = Qt.createComponent("qrc:/main.qml")
        if (c.status === Component.Ready)
            window = c.createObject(null)
        else
            console.warn("[d.qml] stock UI failed too: " + c.errorString())
    }

    // Reads a small text file; calls back with its trimmed contents ("" if missing).
    function readText(path, done) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                done((xhr.responseText || "").trim())
        }
        xhr.open("GET", "file://" + path)
        xhr.send()
    }

    // Tries each candidate in turn; the first that compiles and constructs wins.
    function loadFirst(candidates, errors) {
        if (candidates.length === 0) {
            loadStock(errors.join("; "))
            return
        }
        var dir = candidates[0]
        var c = Qt.createComponent(dir + "/Dashboard.qml")
        if (c.status === Component.Ready) {
            window = c.createObject(null)
            if (window) {
                console.log("[d.qml] loaded " + dir)
                return
            }
            errors.push(dir + ": createObject returned null")
        } else {
            errors.push(dir + ": " + c.errorString())
        }
        console.warn("[d.qml] " + errors[errors.length - 1])
        loadFirst(candidates.slice(1), errors)
    }

    Component.onCompleted: {
        readText(root + "/dash_active", function(active) {
            readText(root + "/dash_prev", function(prev) {
                readText(root + "/dash/RELEASE", function(base) {
                    var baseRel = parseInt(base) || 0
                    var list = []
                    var a = parseInt(active) || 0, p = parseInt(prev) || 0
                    if (a > baseRel) list.push("file://" + root + "/dashv/" + a)
                    if (p > baseRel && p !== a) list.push("file://" + root + "/dashv/" + p)
                    list.push("file://" + root + "/dash")
                    loadFirst(list, [])
                })
            })
        })
    }
}
