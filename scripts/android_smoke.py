"""Drive a real-photo, offline repair flow on a dedicated Android emulator."""

import argparse
from contextlib import closing
from fnmatch import fnmatchcase
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import tempfile
import time
from xml.etree import ElementTree as ET


PACKAGE = "org.reparaai.reparaai"
ACTIVITY = f"{PACKAGE}/.MainActivity"


class Android:
    def __init__(self, adb, serial):
        if not serial.startswith("emulator-"):
            raise ValueError("This smoke test changes airplane mode on a dedicated emulator.")
        self.command = [adb, "-s", serial]
        self.xml = "/sdcard/reparaai-smoke.xml"

    def run(self, *args):
        return subprocess.run(self.command + list(args), check=True, capture_output=True, timeout=90).stdout

    def shell(self, *args):
        return self.run("shell", *map(str, args)).decode("utf-8")

    def nodes(self):
        try:
            result = self.shell("uiautomator", "dump", self.xml)
            if "dumped" not in result:
                return []
            return ET.fromstring(self.run("exec-out", "cat", self.xml)).iter("node")
        except (subprocess.CalledProcessError, ET.ParseError):
            return []

    def find(self, label, seconds=7):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            for node in self.nodes():
                for value in (node.get("text", ""), node.get("content-desc", "")):
                    if fnmatchcase(value.strip(), label):
                        return node
        return None

    def tap(self, label, scroll=False):
        for _ in range(5 if scroll else 1):
            node = self.find(label, seconds=3 if scroll else 12)
            if node is not None:
                x0, y0, x1, y1 = map(int, re.findall(r"\d+", node.attrib["bounds"]))
                self.shell("input", "tap", (x0 + x1) // 2, (y0 + y1) // 2)
                return
            width, height = map(int, re.findall(r"\d+", self.shell("wm", "size").strip().splitlines()[-1]))
            self.shell("input", "swipe", width // 2, height * 4 // 5, width // 2, height // 3, 350)
        raise AssertionError(f"Android element unavailable: {label}")

    def expect(self, label, seconds=18):
        if self.find(label, seconds) is None:
            raise AssertionError(f"Android element unavailable: {label}")

    def restart(self):
        self.shell("am", "force-stop", PACKAGE)
        self.shell("am", "start", "-n", ACTIVITY)

    def screenshot(self, directory, name):
        if directory:
            directory.mkdir(parents=True, exist_ok=True)
            (directory / f"{name}.png").write_bytes(self.run("exec-out", "screencap", "-p"))

    def database(self):
        self.shell("am", "force-stop", PACKAGE)
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary) / "repairs.sqlite"
            for suffix in ("", "-wal", "-shm"):
                try:
                    blob = self.run("exec-out", "run-as", PACKAGE, "cat", f"databases/repairs.sqlite{suffix}")
                except subprocess.CalledProcessError:
                    if not suffix:
                        raise
                    continue
                if blob and not blob.startswith(b"cat:"):
                    base.with_suffix(".sqlite" + suffix).write_bytes(blob)
            with closing(sqlite3.connect(base)) as db:
                return db.execute("""
                    SELECT diagnosis, plan, knowledge, completed_steps, outcome,
                           length(before_photo), length(after_photo)
                    FROM sessions ORDER BY id DESC LIMIT 1
                """).fetchone()


def smoke(args):
    device = Android(args.adb, args.serial)
    prior_airplane = device.shell("settings", "get", "global", "airplane_mode_on").strip()
    if args.apk:
        device.run("install", "-r", str(args.apk))
    if args.photo:
        remote = "/sdcard/Download/reparaai-cisutac-hole.jpg"
        device.run("push", str(args.photo), remote)
        device.shell("am", "broadcast", "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE", "-d", f"file://{remote}")
    device.shell("cmd", "connectivity", "airplane-mode", "enable")
    try:
        if not args.resume_diagnosis:
            device.restart()
            device.expect("Tomar fotografía")
            device.screenshot(args.screenshots, "01-escaner")
            device.tap("Switch to English")
            device.expect("Take a photo")
            device.tap("Cambiar a español")
            device.expect("Tomar fotografía")
            device.tap("Elegir de la galería")
            device.tap("Photo taken on*")
        device.expect("Posible agujero*", seconds=55)
        device.screenshot(args.screenshots, "02-diagnostico")
        device.tap("Daño observado", scroll=True)
        device.tap("Agujero")
        device.tap("Tela confirmada", scroll=True)
        device.tap("Tejido plano no elástico")
        device.tap("Es una prenda de uso cotidiano*", scroll=True)
        device.tap("Iniciar reparación", scroll=True)
        device.expect("Reparación guiada")
        device.screenshot(args.screenshots, "03-reparacion")
        device.tap("Completar paso 1", scroll=True)
        # Reopen a persisted session after terminating the process.
        device.restart()
        device.tap("Historial*")
        device.tap("Parche cosido a mano*")
        device.expect("1 / 3 pasos completados")
        device.tap("Completar paso 2", scroll=True)
        device.tap("Completar paso 3", scroll=True)
        device.tap("Añadir foto del resultado", scroll=True)
        device.tap("Elegir de la galería")
        device.tap("Photo taken on*")
        device.expect("Cambiar foto del resultado", seconds=40)
        device.tap("Guardar resultado", scroll=True)
        device.restart()
        device.tap("Historial*")
        device.expect("Tus reparaciones")
        device.expect("Parche cosido a mano*")
        device.screenshot(args.screenshots, "04-historial")
        device.tap("Parche cosido a mano*")
        device.expect("3 / 3 pasos completados")
        diagnosis, plan, knowledge, completed, outcome, before, after = device.database()
        assert completed == 3 and outcome == "repaired" and before > 0 and after > 0
        assert json.loads(diagnosis)["status"] == "candidate"
        assert json.loads(plan)["id"] == "woven-patch" and json.loads(plan)["url"].startswith("https://")
        result = {"platform": "Android emulator", "serial": args.serial, "mode": "airplane",
                  "languages_checked": ["es", "en"] if not args.resume_diagnosis else ["es"],
                  "fixture": args.photo.name if args.photo else "CISUTAC held-out photo already on emulator",
                  "model": json.loads(diagnosis), "knowledge_version": knowledge, "procedure": "woven-patch",
                  "completed_steps": completed, "outcome": outcome, "before_bytes": before, "after_bytes": after}
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, indent=2))
    finally:
        if prior_airplane != "1":
            device.shell("cmd", "connectivity", "airplane-mode", "disable")
        device.shell("am", "start", "-n", ACTIVITY)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--photo", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--screenshots", type=Path)
    parser.add_argument("--resume-diagnosis", action="store_true")
    smoke(parser.parse_args())
