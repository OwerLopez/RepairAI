"""Drive a real-photo, offline repair flow on a dedicated Android emulator."""

import argparse
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
        return subprocess.run(self.command + list(args), check=True, capture_output=True, timeout=45).stdout

    def shell(self, *args):
        return self.run("shell", *map(str, args)).decode("utf-8")

    def nodes(self):
        result = self.shell("uiautomator", "dump", self.xml)
        if "dumped" not in result:
            return []
        return ET.fromstring(self.run("exec-out", "cat", self.xml)).iter("node")

    def find(self, label, seconds=7):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            for node in self.nodes():
                for value in (node.get("text", ""), node.get("content-desc", "")):
                    if value.strip() == label or (label.endswith("*") and value.startswith(label[:-1])):
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
            with sqlite3.connect(base) as db:
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
            device.tap("Choose from gallery")
            device.tap("Photo taken on*")
        device.expect("Possible hole*", seconds=55)
        device.tap("Observed damage")
        device.tap("Hole")
        device.tap("Confirmed fabric")
        device.tap("Non-stretch woven fabric")
        device.tap("This is an everyday garment*", scroll=True)
        device.tap("Start repair", scroll=True)
        device.expect("Guided repair")
        device.tap("Complete step 1", scroll=True)
        # Reopen a persisted session after terminating the process.
        device.restart()
        device.tap("History*")
        device.tap("Hand-sewn patch*")
        device.expect("1 / 3 steps complete")
        device.tap("Complete step 2", scroll=True)
        device.tap("Complete step 3", scroll=True)
        device.tap("Add outcome photo", scroll=True)
        device.tap("Choose from gallery")
        device.tap("Photo taken on*")
        device.expect("Replace outcome photo", seconds=40)
        device.tap("Save outcome", scroll=True)
        device.restart()
        device.tap("History*")
        device.tap("Hand-sewn patch*")
        device.expect("3 / 3 steps complete")
        diagnosis, plan, knowledge, completed, outcome, before, after = device.database()
        assert completed == 3 and outcome == "repaired" and before > 0 and after > 0
        assert json.loads(diagnosis)["status"] == "candidate"
        assert json.loads(plan)["id"] == "woven-patch" and json.loads(plan)["url"].startswith("https://")
        result = {"platform": "Android emulator", "serial": args.serial, "mode": "airplane",
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--photo", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--resume-diagnosis", action="store_true")
    smoke(parser.parse_args())
