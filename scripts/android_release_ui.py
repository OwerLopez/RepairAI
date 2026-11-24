"""Verify optimized ONNX inference, focused scan and journal UI on Android."""

import argparse
from pathlib import Path
import re

from android_smoke import Android


def main(args):
    device = Android(args.adb, args.serial)
    if args.apk:
        device.run("install", "-r", str(args.apk))
    device.restart()
    if device.find("Cambiar a español", seconds=6) is not None:
        device.tap("Cambiar a español")
    device.expect("Tomar fotografía")
    device.screenshot(args.screenshots, "01-escaner")
    print("Release: Spanish scanner", flush=True)
    device.tap("Elegir de la galería")
    device.tap("Photo taken on*")
    device.expect("Posible agujero*", seconds=60)
    device.screenshot(args.screenshots, "02-diagnostico")
    print("Release: real-photo ONNX candidate", flush=True)
    device.tap("Señalar zona", scroll=True)
    target = device.find("Foto para señalar el daño", seconds=12)
    if target is None:
        raise AssertionError("The area-selection photo was unavailable")
    x0, y0, x1, y1 = map(int, re.findall(r"\d+", target.attrib["bounds"]))
    photo_width = (y1 - y0) * 2160 / 3840
    x = int((x0 + x1) / 2 - photo_width * .15)
    y = int(y0 + (y1 - y0) * .53)
    device.shell("input", "tap", x, y)
    device.tap("Volver al análisis completo", scroll=True)
    print("Release: focused ONNX analysis and return to full-image analysis", flush=True)
    device.restart()
    device.tap("Historial*")
    device.expect("Parche cosido a mano*")
    device.screenshot(args.screenshots, "04-historial")
    device.tap("Parche cosido a mano*")
    device.expect("Reparación guiada")
    device.screenshot(args.screenshots, "03-reparacion")
    device.tap("Diagnóstico y fotos*", scroll=True)
    device.expect("*Comparar antes y después*")
    width, height = map(int, re.findall(r"\d+", device.shell("wm", "size").strip().splitlines()[-1]))
    device.shell("input", "swipe", width // 2, height * 4 // 5, width // 2, height // 3, 350)
    device.expect("*Control de comparación de fotos*")
    device.screenshot(args.screenshots, "05-comparacion")
    print("Release: persisted journal and before/after comparator", flush=True)
    device.restart()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--screenshots", type=Path)
    main(parser.parse_args())
