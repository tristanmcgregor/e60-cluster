// Display conversions shared by the dash pages.
.pragma library

// Tyre pressure as psi. The MCU sends formatted strings such as "2.3 bar", "230 kPa" or
// "33 psi"; a bare number is taken as bar.
function tyrePsi(s) {
    if (!s) return "--"
    var m = String(s).match(/([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]*)/)
    if (!m) return s
    var v = parseFloat(m[1]), unit = m[2].toLowerCase()
    var psi = unit === "psi" ? v : (unit === "kpa" ? v * 0.145038 : v * 14.5038)
    return Math.round(psi) + " psi"
}

// Distance with a unit; the car sends range as a bare number on some models.
function withUnit(s, mph) {
    if (s === undefined || s === null || String(s).trim() === "") return "--"
    var t = String(s).trim()
    return /[a-zA-Z]/.test(t) ? t : t + (mph ? " mi" : " km")
}
