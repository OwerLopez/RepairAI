"""Window descriptors shared by the research pipeline and the Dart detector."""

from dataclasses import dataclass
from pathlib import Path
import re

import numpy as np
from PIL import Image, ImageOps


GRID = 384
SCALES = (8, 16, 32, 64)
GROUP = re.compile(r"^(\d{8}_\d{6}_[0-9a-f]{8})_(?:front|back)_")


@dataclass(frozen=True)
class Record:
    group: str
    split: str
    path: Path
    boxes: np.ndarray
    original_size: tuple[int, int]


def read_export(root):
    """Use the largest export per object/view and split by object ID."""
    variants = {}
    all_exports = 0
    upstream = {}
    for split in ("train", "valid"):
        images = root / split / "images"
        labels = root / split / "labels"
        if {path.stem for path in images.glob("*.jpg")} != {path.stem for path in labels.glob("*.txt")}:
            raise ValueError(f"Image and annotation files must match in {split}")
        for path in sorted(images.glob("*.jpg")):
            match = GROUP.match(path.name)
            if not match:
                raise ValueError(f"Unknown garment ID format: {path.name}")
            all_exports += 1
            group = match.group(1)
            upstream.setdefault(group, set()).add(split)
            view = path.name.split(".rf.")[0]
            fields = [line.split() for line in (labels / f"{path.stem}.txt").read_text().splitlines() if line.strip()]
            parsed = []
            for row in fields:
                if row[0] != "0" or len(row) < 5 or len(row) % 2 == 0 or len(row) == 7:
                    raise ValueError(f"Invalid annotation format: {path.name}")
                coordinates = np.array(row[1:], dtype=float)
                if not np.isfinite(coordinates).all() or np.any(coordinates < 0) or np.any(coordinates > 1):
                    raise ValueError(f"Invalid normalized coordinates: {path.name}")
                if len(coordinates) == 4:
                    center, half = coordinates[:2], coordinates[2:] / 2
                    box = np.clip(np.r_[center - half, center + half], 0, 1)
                else:
                    polygon = coordinates.reshape(-1, 2)
                    box = np.r_[polygon.min(axis=0), polygon.max(axis=0)]
                if np.any(box[2:] <= box[:2]):
                    raise ValueError(f"Degenerate annotation: {path.name}")
                parsed.append(box)
            boxes = np.array(parsed, dtype=float).reshape(-1, 4)
            with Image.open(path) as image:
                dimensions = image.size
            key = (group, view)
            if key not in variants or np.prod(dimensions) > np.prod(variants[key].original_size):
                variants[key] = Record(group, split, path, boxes, dimensions)
    if not variants:
        raise ValueError("No images available. Run ml/acquire.py first.")
    groups = sorted({record.group for record in variants.values()})
    np.random.default_rng(104).shuffle(groups)
    train_end, val_end = int(len(groups) * .70), int(len(groups) * .85)
    assignments = {group: split for split, part in zip(
        ("train", "validation", "test"), (groups[:train_end], groups[train_end:val_end], groups[val_end:])
    ) for group in part}
    records = [
        Record(record.group, assignments[record.group], record.path, record.boxes, record.original_size)
        for record in variants.values()
    ]
    return records, all_exports, sum(len(splits) > 1 for splits in upstream.values())


def windows():
    for size in SCALES:
        for y in range(0, GRID - size + 1, size // 2):
            for x in range(0, GRID - size + 1, size // 2):
                yield x, y, x + size, y + size


WINDOWS = np.array(list(windows()))
BOXES = WINDOWS / GRID


def grayscale(path):
    with Image.open(path) as original:
        rgb = np.asarray(ImageOps.exif_transpose(original).convert("RGB"))
    height, width, _ = rgb.shape
    x = np.arange(GRID) * width // GRID
    y = np.arange(GRID) * height // GRID
    pixels = rgb[y[:, None], x].astype("int32")
    return ((77 * pixels[:, :, 0] + 150 * pixels[:, :, 1] + 29 * pixels[:, :, 2]) // 256).astype(float) / 255


def quality(gray):
    mean = float(gray.mean())
    laplacian = -4 * gray[1:-1, 1:-1] + gray[2:, 1:-1] + gray[:-2, 1:-1] + gray[1:-1, 2:] + gray[1:-1, :-2]
    focus = float(np.mean(laplacian ** 2))
    return .07 <= mean <= .96 and focus >= .00012


def features(gray, locations=WINDOWS):
    padded = np.pad(gray, ((0, 1), (0, 1)), mode="edge")
    gx = np.abs(padded[:-1, 1:] - gray)
    gy = np.abs(padded[1:, :-1] - gray)
    planes = np.stack((gray, gray ** 2, gx, gy, gray < .12, gray > .92), axis=-1)
    integral = np.pad(planes.cumsum(0).cumsum(1), ((1, 0), (1, 0), (0, 0)))

    def mean(x0, y0, x1, y1):
        total = integral[y1, x1] + integral[y0, x0] - integral[y0, x1] - integral[y1, x0]
        return total / ((x1 - x0) * (y1 - y0))[:, None]

    x0, y0, x1, y1 = locations.T
    size = x1 - x0
    quarter = size // 4
    whole = mean(x0, y0, x1, y1)
    center = mean(x0 + quarter, y0 + quarter, x1 - quarter, y1 - quarter)
    around = mean(np.maximum(0, x0 - quarter), np.maximum(0, y0 - quarter),
                  np.minimum(GRID, x1 + quarter), np.minimum(GRID, y1 + quarter))
    mid_x, mid_y = x0 + size // 2, y0 + size // 2
    cells = np.stack((mean(x0, y0, mid_x, mid_y)[:, 0], mean(mid_x, y0, x1, mid_y)[:, 0],
                      mean(x0, mid_y, mid_x, y1)[:, 0], mean(mid_x, mid_y, x1, y1)[:, 0]))
    return np.column_stack((
        whole[:, 0], whole[:, 1] - whole[:, 0] ** 2, whole[:, 2:],
        center[:, 0] - whole[:, 0], whole[:, 0] - around[:, 0],
        center[:, 2:4], whole[:, 2:4] - around[:, 2:4], center[:, 4:],
        cells.T - whole[:, :1], size / GRID,
    ))


def overlaps(windows, boxes):
    intersection = np.maximum(0, np.minimum(windows[:, None, 2:], boxes[:, 2:]) -
                              np.maximum(windows[:, None, :2], boxes[:, :2])).prod(axis=2)
    window_area = (windows[:, 2:] - windows[:, :2]).prod(axis=1)
    box_area = (boxes[:, 2:] - boxes[:, :2]).prod(axis=1)
    return intersection / (window_area[:, None] + box_area - intersection)
