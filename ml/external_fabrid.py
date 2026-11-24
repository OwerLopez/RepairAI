"""Measure domain transfer with the frozen mobile detector on FabriD V1."""

import argparse
import hashlib
from io import BytesIO
import json
import math
from pathlib import Path
from zipfile import ZipFile

import numpy as np
import onnxruntime
from PIL import Image, ImageOps

from experiment import metrics, write_json
from neural import decode, one_prediction
from vision import Record


ARCHIVE_SHA256 = "4944cec7f54ce3f9120ed243ea8c33f3ff3a3d4c39556fd06e7cfe3a5b3a05c3"
SOURCE = "https://doi.org/10.17632/vncdwps24r.1"


def sha256(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def wilson(successes, n):
    center = successes / n
    z = 1.96
    denominator = 1 + z * z / n
    offset = z * math.sqrt(center * (1 - center) / n + z * z / (4 * n * n))
    return [(center + z * z / (2 * n) + sign * offset) / denominator for sign in (-1, 1)]


def annotations(archive, name):
    labels = name.replace("/images/", "/labels/").removesuffix(".jpg") + ".txt"
    boxes = []
    classes = set()
    for row in archive.read(labels).decode().splitlines():
        fields = row.split()
        if not fields:
            continue
        class_index = int(fields[0])
        coordinates = np.array(fields[1:], dtype=float)
        if class_index not in range(4) or len(coordinates) < 6 or len(coordinates) % 2:
            raise ValueError(f"Unexpected FabriD label in {name}")
        if not np.isfinite(coordinates).all() or np.any(coordinates < 0) or np.any(coordinates > 1):
            raise ValueError(f"Out-of-range FabriD polygon in {name}")
        classes.add(class_index)
        if class_index == 1:
            poly = coordinates.reshape(-1, 2)
            box = np.r_[poly.min(0), poly.max(0)]
            if np.all(box[2:] > box[:2]):
                boxes.append(box)
    boxes = np.array(boxes).reshape(-1, 4)
    if 1 in classes and not len(boxes):
        raise ValueError(f"No valid hole box in {name}")
    group = "hole" if 1 in classes else ("other_annotated_defect" if classes else "empty_annotation")
    return group, boxes


def run(args):
    if sha256(args.archive) != ARCHIVE_SHA256:
        raise ValueError("FabriD archive SHA-256 differs from its pinned V1 record")
    config = json.loads(args.model.with_suffix(".json").read_text())
    if sha256(args.model) != config["sha256"]:
        raise ValueError("Detector SHA-256 differs from its mobile metadata")
    opts = onnxruntime.SessionOptions()
    opts.intra_op_num_threads = args.threads
    session = onnxruntime.InferenceSession(str(args.model), opts, providers=["CPUExecutionProvider"])
    size, resolution, starts = config["grid"], config["input_grid"], config["tile_starts"]
    rows = {"hole": [], "empty_annotation": [], "other_annotated_defect": []}
    with ZipFile(args.archive) as archive:
        yaml = archive.read("data.yaml").decode()
        if "['Needle Mark Defect', 'hole Defect', 'missing yarn Defect', 'stain Defect']" not in yaml:
            raise ValueError("Unknown FabriD class mapping")
        images = sorted(name for name in archive.namelist()
                        if name.startswith("test/images/") and name.endswith(".jpg"))
        if len(images) != 358 or len({Path(name).name.split(".rf.")[0] for name in images}) != len(images):
            raise ValueError("Unexpected size or repeated capture prefix in FabriD test view set")
        for index, name in enumerate(images, 1):
            group, boxes = annotations(archive, name)
            with Image.open(BytesIO(archive.read(name))) as original:
                rgb = np.array(ImageOps.exif_transpose(original).convert("RGB"))
            height, width = rgb.shape[:2]
            prepared = rgb[np.arange(resolution)[:, None] * height // resolution,
                           np.arange(resolution) * width // resolution]
            best, box = -1.0, None
            for y in starts:
                for x in starts:
                    tile = prepared[y:y+size, x:x+size].transpose(2, 0, 1)[None].astype(np.float32) / 255
                    heat, geometry = session.run(None, {"image": np.ascontiguousarray(tile)})
                    score, local = decode(heat[0], geometry[0])
                    if score > best:
                        best, box = score, (local * size + [x, y, x, y]) / resolution
            basename = Path(name).name
            record = Record(basename.split(".rf.")[0], "external-test", Path(basename), boxes, (width, height))
            row = one_prediction(prepared[::resolution // size, ::resolution // size], record, best, box)
            row["quality"] = row["quality"] and min(width, height) >= size
            rows[group].append(row)
            if index % 50 == 0:
                print(f"FabriD V1 test: {index}/{len(images)} views", flush=True)
    summary = {}
    for group, entries in rows.items():
        counts = metrics(entries, config["threshold"])
        summary[group] = {**counts, "coverage_wilson_95": wilson(counts["shown"], len(entries)),
                          "quality_rejected": sum(not row["quality"] for row in entries)}
    report = {"source": SOURCE, "archive_sha256": ARCHIVE_SHA256, "model": config["version"],
              "threshold": config["threshold"], "test_only": summary}
    write_json(args.report, report)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, default=Path(".data/fabrid-u1.zip"))
    parser.add_argument("--model", type=Path, default=Path("apps/mobile/assets/hole_tile.onnx"))
    parser.add_argument("--report", type=Path, default=Path("research/experiments/external_fabrid.json"))
    parser.add_argument("--threads", type=int, default=4)
    run(parser.parse_args())
