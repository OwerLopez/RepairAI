"""Evaluate a simulated tap on the held-out CISUTAC views using the mobile ONNX."""

import json
from pathlib import Path

import numpy as np
import onnxruntime
from PIL import Image, ImageOps

from experiment import metrics, write_json
from neural import decode, one_prediction
from vision import read_export


def run():
    model = Path("apps/mobile/assets/hole_tile.onnx")
    config = json.loads(model.with_suffix(".json").read_text())
    opts = onnxruntime.SessionOptions()
    opts.intra_op_num_threads = 4
    session = onnxruntime.InferenceSession(str(model), opts, providers=["CPUExecutionProvider"])
    views = [record for record in read_export(Path(".data/holes"))[0] if record.split == "test"]
    rng = np.random.default_rng(203)
    size, resolution, stride = config["grid"], config["input_grid"], config["stride"]
    canvas = np.arange(resolution)
    centers = (np.arange(size // stride) + .5) * stride
    rows = []
    for record in views:
        with Image.open(record.path) as original:
            rgb = np.array(ImageOps.exif_transpose(original).convert("RGB"))
        height, width = rgb.shape[:2]
        prepared = rgb[canvas[:, None] * height // resolution, canvas * width // resolution]
        largest = record.boxes[(record.boxes[:, 2:] - record.boxes[:, :2]).prod(1).argmax()]
        center = np.clip(largest.reshape(2, 2).mean(axis=0) + rng.uniform(-.06, .06, 2), 0, 1)
        low, high = center - .10, center + .10
        best, box = -1.0, None
        for y in config["tile_starts"]:
            cy = (y + centers) / resolution
            for x in config["tile_starts"]:
                cx = (x + centers) / resolution
                eligible = ((cy[:, None] >= low[1]) & (cy[:, None] < high[1]) &
                            (cx >= low[0]) & (cx < high[0]))
                if not eligible.any():
                    continue
                tile = prepared[y:y+size, x:x+size].transpose(2, 0, 1)[None].astype(np.float32) / 255
                heat, geometry = session.run(None, {"image": np.ascontiguousarray(tile)})
                score, local = decode(heat[0], geometry[0], eligible)
                if score > best:
                    best, box = score, (local * size + [x, y, x, y]) / resolution
        rows.append(one_prediction(prepared[::resolution // size, ::resolution // size], record, best, box))
    report = {
        "model": config["version"], "threshold": config["threshold"],
        "focus_size": .20, "uniform_jitter_each_axis": .06, "seed": 203,
        "mark_source": "simulated from largest expert-annotated box",
        "test": metrics(rows, config["threshold"]),
    }
    write_json(Path("research/experiments/guided_results.json"), report)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    run()
