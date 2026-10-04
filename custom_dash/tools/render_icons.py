#!/usr/bin/env python3
"""Render Material Symbols (Apache 2.0) and Tabler (MIT) SVGs from icons/src to pre-tinted PNGs in device/etc/dash/icons.

Pre-tinting avoids a ColorOverlay pass per icon on the cluster's GPU.
"""
import os, sys
from PyQt5.QtCore import QRectF, Qt
from PyQt5.QtGui import QColor, QGuiApplication, QImage, QPainter
from PyQt5.QtSvg import QSvgRenderer

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "icons", "src")
OUT = os.path.join(HERE, "..", "device", "etc", "dash", "icons")

# output name: (svg, colour, pixel size)
ICONS = {
    "fuel":         ("local_gas_station", "#c9d0da", 64),
    "fuel_warn":    ("local_gas_station", "#ff6b60", 64),
    "temp":         ("thermostat",        "#c9d0da", 64),
    "temp_warn":    ("thermostat",        "#ff6b60", 64),
    "turn_left_on": ("arrow-big-left",        "#2bd96b", 96),
    "turn_left_off":("arrow-big-left",        "#1d2a22", 96),
    "turn_right_on":("arrow-big-right",       "#2bd96b", 96),
    "turn_right_off":("arrow-big-right",      "#1d2a22", 96),
}

# Turn-by-turn arrows for the nav card (white, recoloured in QML only by opacity)
for _n in ("turn_left", "turn_right", "turn_slight_left", "turn_slight_right", "turn_sharp_left",
           "turn_sharp_right", "u_turn_left", "u_turn_right", "roundabout_left", "roundabout_right",
           "fork_left", "fork_right", "merge", "ramp_left", "ramp_right", "straight", "flag",
           "directions_boat", "navigation"):
    ICONS["nav_" + _n] = (_n, "#ffffff", 160)

ICONS["service"] = ("build", "#ffb340", 128)
ICONS["media_note"] = ("music_note", "#c9d0da", 64)
ICONS["call_in"] = ("call", "#35d07f", 64)
ICONS["call_end"] = ("call_end", "#ff4d4d", 64)
# car warnings (CarWarnings.qml) and the performance timer
ICONS["battery_warn"] = ("battery_alert", "#ff6b60", 128)
ICONS["oil_warn"] = ("oil_barrel", "#ff6b60", 128)
ICONS["coolant_warn"] = ("thermostat", "#ff6b60", 128)
ICONS["warmup"] = ("oil_barrel", "#8a7cff", 64)
ICONS["timer"] = ("timer", "#ff3b30", 64)
# over-the-air update downloaded (UpdateWatch.qml)
ICONS["update"] = ("system_update_alt", "#5ab0ff", 64)
# Classic BMW amber theme (Theme.classic)
ICONS["fuel_classic"] = ("local_gas_station", "#e09a50", 64)
ICONS["temp_classic"] = ("thermostat", "#e09a50", 64)
ICONS["media_note_classic"] = ("music_note", "#e09a50", 64)

def main():
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    app = QGuiApplication(sys.argv)
    os.makedirs(OUT, exist_ok=True)
    for name, (svg, colour, px) in ICONS.items():
        r = QSvgRenderer(os.path.join(SRC, svg + ".svg"))
        img = QImage(px, px, QImage.Format_ARGB32_Premultiplied)
        img.fill(Qt.transparent)
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing)
        r.render(p, QRectF(0, 0, px, px))
        p.setCompositionMode(QPainter.CompositionMode_SourceIn)   # recolour, keep alpha
        p.fillRect(img.rect(), QColor(colour))
        p.end()
        img.save(os.path.join(OUT, name + ".png"))
        print("wrote", name + ".png", px)

if __name__ == "__main__":
    main()
