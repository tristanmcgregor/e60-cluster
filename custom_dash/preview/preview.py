#!/usr/bin/env python3
"""
Desktop preview of the custom dashboard with a fake EventHub.

    python3 preview.py                 # live window, simulated drive
    python3 preview.py --shot out.png  # render one frame to PNG and exit

Registers a mock `plugins.EventHub 1.0` type exposing the same property
names / NOTIFY groups the real libEventHub.so has, then loads the exact
device files from ../device/etc/dash/Dashboard.qml.
"""
import argparse
import math
import os
import sys

from PyQt5.QtCore import QObject, QTimer, QUrl, pyqtProperty, pyqtSignal
from PyQt5.QtGui import QFontDatabase, QGuiApplication
from PyQt5.QtQml import QQmlComponent, QQmlEngine, qmlRegisterType

HERE = os.path.dirname(os.path.abspath(__file__))
DASH = os.path.join(HERE, "..", "device", "etc", "dash", "Dashboard.qml")
FONT_DIRS = [
    os.path.join(HERE, "fonts"),
    os.path.join(HERE, "..", "fonts_candidates"),
    "/private/tmp/claude-501/-Users-tritty-Documents-code-JLY/22db9255-63f4-42f4-b887-91fa283eb1b1/scratchpad/pkg/dashboard/usr/share/fonts",
]


def group(signal_name, props):
    """Build read-only pyqtProperties sharing one NOTIFY signal, like EventHub."""
    return signal_name, props


GROUPS = [
    ("speedChanged", {"speed": int, "speedM": int, "rpm": int}),
    ("fuelChanged", {"fuel": int, "remindingRange": str, "remindingRangeM": str,
                     "instantFuel": str, "instantFuelUnit": str}),
    ("waterChanged", {"waterPercetage": int, "waterTemperature": str, "waterTemperatureF": str}),
    ("tripChanged", {"odo": str, "odoM": str, "tripA": str, "tripAmile": str, "tripB": str, "tripBmile": str}),
    ("cruiseChanged", {"cruiseShowSetSpeed": int, "cruiseShowCtrlIndicator": int, "cruiseSetSpeed": str}),
    ("resetChanged", {"resetAvgFuel": str, "resetAvgSpeed": str, "resetDistance": str, "resetDuration": str}),
    ("tpmsChanged", {"flTire": str, "frTire": str, "rlTire": str, "rrTire": str,
                     "flTireState": int, "frTireState": int, "rlTireState": int, "rrTireState": int}),
    ("dashboardChanged", {"outsideTemp": str, "oilTemp": str, "oilTempInt": int, "batteryVoltage": int}),
    ("gearChanged", {"gear": str, "gearShow": bool, "gearAuto": int, "gearManual": int}),
    ("turnChanged", {"turnLeft": bool, "turnRight": bool, "turnLeftState": bool, "turnRightState": bool}),
    ("warningChanged", {"warningId": int, "warningDuration": int}),
    ("doorChanged", {"lfDoor": int, "lrDoor": int, "rfDoor": int, "rrDoor": int, "trunk": int, "hood": int}),
    ("overspeedChanged", {"overspeedOn": int, "overspeedFlicker": int}),
    ("alarmtableChanged", {"alarmTableMax": int}),
    ("swcChanged", {"swcKey": int, "swcKeyPress": bool}),
    ("maintainChanged", {"maintainItemId": int, "maintainState": int, "maintainMileage": str,
                         "maintainReminder": str, "maintainYear": str, "maintainMonth": str,
                         "maintainDay": str, "maintainDuration": int}),
    ("accChanged", {"acc": int}),
    ("versionNotify", {"version": str, "canVersion": str}),
]
ICON_BASE = os.path.join(HERE, "..", "..", "launcher_ui_assets", "bundle_1")

# --scene: which warning features the fake car exercises
SCENES = {
    "normal": {},
    # engine (on), ABS (fast flash), handbrake (on), low oil pressure (slow flash), high beam, cruise on
    "alarms": {"alarms": {2: 1, 4: 2, 23: 1, 25: 3, 9: 1, 31: 1}},
    "door": {"doors": {"lfDoor": 1, "trunk": 1}},
    "warning": {"warning": (150, 8)},
    "overspeed": {"overspeed": True},
    # fake head unit streams a route over ws://127.0.0.1:8765 (fake_headunit.py)
    "nav": {"nav": True},
    "cruise": {"cruise": True},
    # nav + a stand-in for the native map plugin (preview/qml/ClusterVideo)
    "map": {"nav": True, "map": True},
    "fullmap": {"nav": True, "map": True, "fh": "limit60", "keys": [(4.0, 26 + 128)]},
    # centre menu pages: BC (26) presses step TRIP -> VEHICLE -> NAVIGATION -> INFO
    "page_trip": {},
    "page_fuel": {"keys": [(13.0, 21), (13.3, 21)], "fastfuel": True, "fueljump": (20, 75, 6.0), "range": "25", "nav": True},
    "page_vehicle": {"keys": [(1.0, 26), (1.3, 26)]},
    "page_info": {"keys": [(1.0, 26), (1.3, 26), (1.6, 26), (1.9, 26)]},
    # BC physically held (the MCU sends plain 26 on press and release; the dash times the hold)
    "fullmap_hold": {"nav": True, "map": True, "fh": "limit60", "keys": [(3.0, 26, 1.5)]},
    "page_dev_hold": {"keys": [(1.0, 26), (1.3, 26), (1.6, 26), (1.9, 26), (2.3, 26, 1.2)]},
    "page_dev": {"keys": [(1.0, 26), (1.3, 26), (1.6, 26), (1.9, 26), (2.3, 26 + 128)]},
    "msg": {"warning": (58, 8)},
    # the MCU repeating one check-control message every 3 s: shown once, not again
    "msg_repeat": {"warning": (58, 8), "warningEvery": 3.0},
    "media": {"nav": True, "fh": "media"},
    "call": {"nav": True, "fh": "call"},
    "media_art": {"nav": True, "fh": "media_art"},
    "settings": {"nav": True, "fh": "settings", "gear": "D3", "rpm": 5200, "oil": 65},
    "limit": {"nav": True, "fh": "limit130"},
    "limit_over": {"nav": True, "fh": "limit60"},
    "service": {"service": True},
    "startup": {},
    # sport layout: gearbox in S / M; "cold" shows the warm-up redline
    "sport": {"gear": "S3", "rpm": 5600},
    "sport_shift": {"gear": "M4", "rpm": 6900},
    "sport_cold": {"gear": "S2", "rpm": 3900, "oil": 45},
    "cold": {"gear": "D2", "oil": 45},
    "launch": {"launch": True, "gear": "S1", "rpm": 4800},
    "carwarn": {"coolant": "118°C", "volts": 121},
    # head unit GPS features (SpeedLimits): school zone in force, camera countdown, GPS speed check
    "school": {"nav": True, "fh": "school"},
    "camera": {"nav": True, "fh": "camera"},
    "redlight": {"nav": True, "fh": "redlight"},
    "gps_dev": {"nav": True, "fh": "gps", "keys": [(1.0, 26), (1.3, 26), (1.6, 26), (1.9, 26), (2.3, 26 + 128)]},
    # S61dashupdate installs release 99 a second in (UpdateWatch popup); "update_info" then opens INFO
    "update": {"update": True},
    "update_info": {"update": True, "keys": [(10.0, 26), (10.3, 26), (10.6, 26), (10.9, 26)]},
}
SCENE = SCENES["normal"]
WRITABLE = {"port": int, "packetDebug": int, "MPH": int, "verified": int, "menuId": int, "uiStyle": int}


def make_hub_class():
    ns = {}
    for sig, _ in GROUPS:
        ns[sig] = pyqtSignal()
    ns["unitChanged"] = pyqtSignal()
    ns["portChanged"] = pyqtSignal()

    def ro(name, typ, sig):
        return pyqtProperty(typ, lambda self: self._v[name], notify=ns[sig])

    for sig, props in GROUPS:
        for name, typ in props.items():
            ns[name] = ro(name, typ, sig)

    def rw(name, typ, sig=None):
        def get(self):
            return self._v[name]

        def set_(self, v):
            self._v[name] = v
            if sig:
                getattr(self, sig).emit()

        kw = {"notify": ns[sig]} if sig else {}
        return pyqtProperty(typ, get, set_, **kw)

    ns["port"] = rw("port", int, "portChanged")
    ns["packetDebug"] = rw("packetDebug", int)
    ns["MPH"] = rw("MPH", int, "unitChanged")
    ns["verified"] = rw("verified", int)
    ns["menuId"] = rw("menuId", int)      # on the device, writing this sends the MCU the interface packet
    ns["uiStyle"] = rw("uiStyle", int)

    # alarmTable: write an index, read back that alarm's state (no NOTIFY on write, like the device)
    def at_get(self):
        return SCENE.get("alarms", {}).get(self._at, 0)

    def at_set(self, i):
        self._at = i

    ns["alarmTable"] = pyqtProperty(int, at_get, at_set, notify=ns["alarmtableChanged"])

    def __init__(self, parent=None):
        QObject.__init__(self, parent)
        self._v = {}
        for _, props in GROUPS:
            for n, t in props.items():
                self._v[n] = t()
        for n, t in WRITABLE.items():
            self._v[n] = t()
        self._t = 0.0
        self._at = 0
        self._v["alarmTableMax"] = 232
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._tick)
        self._timer.start(50)
        self._tick()

    def _tick(self):
        t = self._t = self._t + 0.05
        v = self._v
        kmh = int(60 + 55 * math.sin(t / 4))
        if SCENE.get("launch"):                  # stand 2 s, then a steady 12.5 km/h per second
            kmh = 0 if t < 2 else min(130, int((t - 2) * 12.5))
        v["speed"], v["speedM"] = kmh, int(kmh / 1.609)
        v["rpm"] = int(1800 + 2600 * (0.5 + 0.5 * math.sin(t * 1.3)) + 900 * math.sin(t / 4))
        if "rpm" in SCENE:                       # sport scenes: a fixed rpm, or a rising pull
            v["rpm"] = SCENE["rpm"] if isinstance(SCENE["rpm"], int) else int(3000 + (t * 900) % 4400)
        self.speedChanged.emit()
        if int(t * 20) % 20 == 0:
            v["fuel"] = 62
            v["remindingRange"], v["remindingRangeM"] = "438", "272"
            v["waterPercetage"] = 52
            v["waterTemperature"], v["waterTemperatureF"] = SCENE.get("coolant", "90°C"), "194°F"
            v["odo"], v["odoM"] = "187432km", "116464mi"
            v["tripA"], v["tripAmile"] = "312.4km", "194.1mi"
            oil = SCENE.get("oil", 104)
            v["outsideTemp"], v["oilTemp"], v["oilTempInt"], v["batteryVoltage"] = "18°C", f"{oil}°C", oil, SCENE.get("volts", 142)
            v["gear"], v["gearShow"] = SCENE.get("gear", "D3"), True
            v["instantFuel"], v["instantFuelUnit"] = "%.1f" % (9.5 + 4 * abs(math.sin(t * 1.7))), "L/100km"
            if "fueljump" in SCENE:              # (before %, after %, at seconds): a refuel
                lo, hi, at = SCENE["fueljump"]
                v["fuel"] = lo if t < at else hi
            if "range" in SCENE:
                v["remindingRange"] = SCENE["range"]
            v["tripB"], v["tripBmile"] = "1204.6km", "748.5mi"
            v["resetAvgFuel"], v["resetAvgSpeed"] = "11.2 L/100km", "54 km/h"
            v["resetDistance"], v["resetDuration"] = "312.4 km", "5:47"
            v["flTire"], v["frTire"], v["rlTire"], v["rrTire"] = "2.3 bar", "2.3 bar", "2.5 bar", "2.4 bar"
            v["cruiseShowSetSpeed"], v["cruiseSetSpeed"] = (1, "100") if SCENE.get("cruise") else (0, "")
            v["version"], v["canVersion"] = "EventHub@20230416 r19154", "129A.V01 2024/6/4"
            for sig in ("fuelChanged", "waterChanged", "tripChanged", "dashboardChanged", "gearChanged",
                        "cruiseChanged", "resetChanged", "tpmsChanged", "versionNotify"):
                getattr(self, sig).emit()
        # scripted button presses: SCENE["keys"] = [(seconds, code), ...], sent as press + release;
        # (seconds, code, held seconds) holds the button down that long before the release
        for key in SCENE.get("keys", []):
            at, code, held = key if len(key) == 3 else key + (0,)
            if abs(t - at) < 0.026:
                v["swcKey"], v["swcKeyPress"] = code, True
                self.swcChanged.emit()
            if abs(t - at - held) < 0.026:
                v["swcKey"], v["swcKeyPress"] = code, False
                self.swcChanged.emit()
        every = SCENE.get("warningEvery")
        if every and t > 1 and abs((t - 0.5) % every) < 0.026:
            v["warningId"], v["warningDuration"] = SCENE["warning"]
            self.warningChanged.emit()
        if abs(t - 0.5) < 0.026:
            self.alarmtableChanged.emit()
            for k, val in SCENE.get("doors", {}).items():
                v[k] = val
            self.doorChanged.emit()
            if "warning" in SCENE:
                v["warningId"], v["warningDuration"] = SCENE["warning"]
                self.warningChanged.emit()
            if SCENE.get("service"):
                v["maintainItemId"], v["maintainState"] = 0, 1
                v["maintainMileage"], v["maintainReminder"] = "1500km", "1500 km"
                v["maintainYear"], v["maintainMonth"], v["maintainDay"] = "2026", "11", "20"
                v["maintainDuration"] = 8
                self.maintainChanged.emit()
            if SCENE.get("overspeed"):
                v["overspeedOn"], v["overspeedFlicker"] = 1, 1
                self.overspeedChanged.emit()
        blink = int(t * 2.5) % 2 == 0 and (t % 12) < 4
        if blink != v["turnLeftState"]:
            v["turnLeftState"] = blink
            self.turnChanged.emit()

    ns["__init__"] = __init__
    ns["_tick"] = _tick
    return type("EventHub", (QObject,), ns)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", help="write a single frame to this PNG and exit")
    ap.add_argument("--classic", action="store_true", help="Classic BMW amber theme (Theme.classic)")
    ap.add_argument("--time", type=float, default=2.5, help="sim seconds before --shot")
    ap.add_argument("--scene", choices=sorted(SCENES), default="normal")
    ap.add_argument("--font", help="override the dash typeface (family name)")
    args = ap.parse_args()
    global SCENE
    SCENE = SCENES[args.scene]
    if not SCENE.get("nav") and os.path.exists("/tmp/nav_gateway"):
        os.remove("/tmp/nav_gateway")

    if args.shot:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ.setdefault("QT_QUICK_BACKEND", "software")
    app = QGuiApplication(sys.argv)
    for d in FONT_DIRS:
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.lower().endswith((".ttf", ".otf")):
                    QFontDatabase.addApplicationFont(os.path.join(d, f))

    # Keep a reference: qmlRegisterType does not, and a collected class crashes QML later.
    global HUB_CLASS
    HUB_CLASS = make_hub_class()
    qmlRegisterType(HUB_CLASS, "plugins.EventHub", 1, 0, "EventHub")
    engine = QQmlEngine()
    # fresh LocalStorage per run, so settings stored by one scene don't leak into the next
    import tempfile
    engine.setOfflineStoragePath(tempfile.mkdtemp(prefix="dashpreview-"))
    if args.font:
        engine.rootContext().setContextProperty("dashFont", args.font)
    if SCENE.get("fastfuel"):                    # FuelTracker: one graph bar per 0.25 s
        engine.rootContext().setContextProperty("dashFastFuel", True)
    if args.classic:
        engine.rootContext().setContextProperty("dashClassic", True)
    if SCENE.get("update"):                      # stands in for /etc/dash_active
        active = os.path.join(tempfile.mkdtemp(prefix="dashactive-"), "dash_active")
        with open(active, "w") as f:
            f.write("0\n")
        def install():
            with open(active, "w") as f:
                f.write("99\n")
        QTimer.singleShot(1000, install)
        engine.rootContext().setContextProperty("dashActiveFile", QUrl.fromLocalFile(active).toString())
    if SCENE.get("map"):
        engine.addImportPath(os.path.join(HERE, "qml"))
    engine.rootContext().setContextProperty("dashIconBase", QUrl.fromLocalFile(os.path.abspath(ICON_BASE) + "/").toString())
    comp = QQmlComponent(engine, QUrl.fromLocalFile(os.path.abspath(DASH)))
    win = comp.create()
    if win is None:
        for e in comp.errors():
            print("QML ERROR:", e.toString())
        sys.exit(1)

    if SCENE.get("nav"):
        # Started only after the QML exists: with it running during comp.create(),
        # PyQt crashes constructing the mock EventHub (sip createPyObject).
        import atexit, subprocess
        fake = subprocess.Popen([sys.executable, os.path.join(HERE, "fake_headunit.py"), SCENE.get("fh", "nav")],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        atexit.register(fake.terminate)

    win.setProperty("width", 1600)
    win.setProperty("height", 600)
    if args.shot:
        def snap():
            from PyQt5 import sip
            from PyQt5.QtQuick import QQuickWindow
            img = sip.cast(win, QQuickWindow).grabWindow()
            print("grab", img.width(), img.height(), img.isNull(), "saved", img.save(os.path.abspath(args.shot)))
            print("wrote", args.shot)
            app.quit()
        QTimer.singleShot(int(args.time * 1000), snap)
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
