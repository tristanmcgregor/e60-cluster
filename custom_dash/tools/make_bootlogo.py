#!/usr/bin/env python3
"""Render the BMW roundel (custom_dash/branding/BMW.svg, from Wikimedia Commons
File:BMW.svg) into the boot screens:

  custom_dash/device/bootlogo/bootlogo.bmp   cluster U-Boot logo, 1920x720 24-bit BMP;
                                             the stock USB installer copies
                                             dashboard/bootlogo/bootlogo.bmp to the boot partition
  custom_dash/device/etc/dash/icons/roundel.png  start-up welcome card in the dash's centre
  headunit/.../res/drawable-*/splash_logo.png  head unit app launch screen (160dp)

    python3 custom_dash/tools/make_bootlogo.py
"""
import os
import sys

from PyQt5.QtCore import QRectF, Qt
from PyQt5.QtGui import QColor, QGuiApplication, QImage, QPainter
from PyQt5.QtSvg import QSvgRenderer

HERE = os.path.dirname(os.path.abspath(__file__))
JLY = os.path.normpath(os.path.join(HERE, "..", ".."))
SVG = os.path.join(JLY, "custom_dash", "branding", "BMW.svg")
BMP = os.path.join(JLY, "custom_dash", "device", "bootlogo", "bootlogo.bmp")
RES = os.path.join(JLY, "headunit", "open-headunit", "app", "src", "main", "res")
DENSITIES = {"mdpi": 160, "hdpi": 240, "xhdpi": 320, "xxhdpi": 480, "xxxhdpi": 640}


def render(svg, w, h, size, background):
    img = QImage(w, h, QImage.Format_ARGB32)
    img.fill(background)
    p = QPainter(img)
    p.setRenderHint(QPainter.Antialiasing)
    p.setRenderHint(QPainter.SmoothPixmapTransform)
    svg.render(p, QRectF((w - size) / 2, (h - size) / 2, size, size))
    p.end()
    return img


def main():
    QGuiApplication(sys.argv[:1] + ["-platform", "offscreen"])
    svg = QSvgRenderer(SVG)
    if not svg.isValid():
        sys.exit(f"cannot read {SVG}")

    # Cluster: roundel centred on black. U-Boot wants a plain uncompressed BMP, so 24-bit RGB.
    os.makedirs(os.path.dirname(BMP), exist_ok=True)
    cluster = render(svg, 1920, 720, 440, QColor("black")).convertToFormat(QImage.Format_RGB888)
    if not cluster.save(BMP, "BMP"):
        sys.exit(f"cannot write {BMP}")
    print("wrote", BMP)

    # Dash welcome card
    out = os.path.join(JLY, "custom_dash", "device", "etc", "dash", "icons", "roundel.png")
    render(svg, 200, 200, 200, QColor(Qt.transparent)).save(out, "PNG")
    print("wrote", out)

    # Head unit: transparent square; splash_background supplies the black.
    for density, px in DENSITIES.items():
        out = os.path.join(RES, f"drawable-{density}", "splash_logo.png")
        render(svg, px, px, px, QColor(Qt.transparent)).save(out, "PNG")
        print("wrote", out)


if __name__ == "__main__":
    main()
