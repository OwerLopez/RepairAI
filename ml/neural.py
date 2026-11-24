"""Train and evaluate a single-class center-heatmap detector on grouped views."""

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import onnxruntime
from PIL import Image, ImageOps
import torch
from torch import nn
from torch.nn import functional as F

from experiment import IOU, SEED, choose_threshold, intervals, metrics, write_json
from vision import quality, read_export


SIZE = 384
STRIDE = 4
CELLS = SIZE // STRIDE
TILE_GRID = SIZE * 3
TILE_STARTS = (0, 256, 512, 768)


def conv(a, b, stride=1):
    return nn.Sequential(nn.Conv2d(a, b, 3, stride, 1, bias=False), nn.BatchNorm2d(b), nn.SiLU())


class CenterDetector(nn.Module):
    def __init__(self):
        super().__init__()
        self.stem = nn.Sequential(conv(3, 16, 2), conv(16, 24, 2), conv(24, 32))
        self.context = nn.Sequential(conv(32, 48, 2), conv(48, 64, 2), conv(64, 64), conv(64, 48))
        self.merge = nn.Sequential(conv(80, 48), conv(48, 32))
        self.heatmap = nn.Conv2d(32, 1, 1)
        self.geometry = nn.Conv2d(32, 4, 1)
        nn.init.constant_(self.heatmap.bias, -2.19)

    def forward(self, rgb):
        details = self.stem(rgb)
        context = F.interpolate(self.context(details), scale_factor=4, mode="nearest")
        merged = self.merge(torch.cat((details, context), dim=1))
        return self.heatmap(merged), self.geometry(merged)


def load_views(records, tiled):
    size = TILE_GRID if tiled else SIZE
    views = []
    for record in records:
        with Image.open(record.path) as original:
            rgb = np.array(ImageOps.exif_transpose(original).convert("RGB"))
        h, w = rgb.shape[:2]
        rgb = np.ascontiguousarray(rgb[np.arange(size)[:, None] * h // size, np.arange(size) * w // size])
        views.append((rgb, record))
    return views


def crop_tile(rgb, boxes, left, top):
    local = (boxes * TILE_GRID - [left, top, left, top]) / SIZE
    center = (local[:, :2] + local[:, 2:]) / 2
    local = np.clip(local[((center >= 0) & (center < 1)).all(1)], 0, 1)
    return rgb[top:top+SIZE, left:left+SIZE], local


def training_crop(rgb, boxes, rng):
    if len(boxes) and rng.random() < .70:
        x, y = (boxes[rng.integers(len(boxes))].reshape(2, 2).mean(axis=0) * TILE_GRID).astype(int)
        left = int(np.clip(x - rng.integers(40, SIZE - 40), 0, TILE_GRID - SIZE))
        top = int(np.clip(y - rng.integers(40, SIZE - 40), 0, TILE_GRID - SIZE))
    else:
        left, top = rng.integers(TILE_GRID - SIZE + 1, size=2)
    return crop_tile(rgb, boxes, left, top)


def augmented(rgb, boxes, rng, tiled):
    rgb, boxes = training_crop(rgb, boxes, rng) if tiled else (rgb, boxes.copy())
    if rng.random() < .5:
        rgb = rgb[:, ::-1].copy()
        boxes[:, [0, 2]] = 1 - boxes[:, [2, 0]]
    if rng.random() < .5:
        rgb = rgb[::-1].copy()
        boxes[:, [1, 3]] = 1 - boxes[:, [3, 1]]
    if not tiled and rng.random() < .35 and len(boxes):
        # Close detail views retain part of the original image around a known annotation.
        x, y = ((boxes[rng.integers(len(boxes))].reshape(2, 2).mean(axis=0)) * SIZE).astype(int)
        side = int(rng.integers(SIZE // 2, int(SIZE * .90)))
        left = max(0, min(SIZE - side, x - int(rng.uniform(.22, .78) * side)))
        top = max(0, min(SIZE - side, y - int(rng.uniform(.22, .78) * side)))
        rgb = np.array(Image.fromarray(rgb[top:top+side, left:left+side]).resize((SIZE, SIZE), Image.Resampling.BILINEAR))
        boxes = (boxes * SIZE - [left, top, left, top]) / side
        boxes = boxes[(boxes[:, :2] >= 0).all(1) & (boxes[:, 2:] <= 1).all(1)]
    if rng.random() < .7:
        rgb = (rgb.astype(np.float32) * rng.uniform(.8, 1.2) + rng.uniform(-15, 15)).clip(0, 255).astype(np.uint8)
    return np.ascontiguousarray(rgb), boxes


def targets(boxes):
    heatmap = np.zeros((1, CELLS, CELLS), dtype=np.float32)
    state = np.zeros((4, CELLS, CELLS), dtype=np.float32)
    for box in boxes:
        left, top, right, bottom = box * CELLS
        cx, cy = (left + right) / 2, (top + bottom) / 2
        x, y = min(CELLS - 1, int(cx)), min(CELLS - 1, int(cy))
        w, h = right - left, bottom - top
        sigma = max(.6, min(2.0, min(w, h) / 3))
        reach = math.ceil(sigma * 3)
        left, right = max(0, x - reach), min(CELLS, x + reach + 1)
        top, bottom = max(0, y - reach), min(CELLS, y + reach + 1)
        dy, dx = np.ogrid[top-y:bottom-y, left-x:right-x]
        cells = heatmap[0, top:bottom, left:right]
        np.maximum(cells, np.exp(-(dy**2 + dx**2) / (2 * sigma**2)), out=cells)
        state[:, y, x] = (cx - x, cy - y, math.log(w), math.log(h))
    return heatmap, state


def loss(prediction, geometry, expected, target):
    probability = prediction.sigmoid().clamp(1e-6, 1 - 1e-6)
    at_center = expected == 1
    positives = at_center.sum().clamp_min(1)
    focal = torch.where(
        at_center,
        -(1 - probability).square() * probability.log(),
        -(1 - expected).pow(4) * probability.square() * torch.log1p(-probability),
    ).sum() / positives
    regression = F.smooth_l1_loss(geometry, target, reduction="none")
    return focal + regression.masked_fill(~at_center, 0).sum() / positives


def tensor(rgb, device):
    return torch.from_numpy(np.ascontiguousarray(np.moveaxis(rgb, -1, -3))).to(device, dtype=torch.float32) / 255


def decode(logits, geometry):
    y, x = np.unravel_index(logits[0].argmax(), logits[0].shape)
    score = float(1 / (1 + np.exp(-np.clip(logits[0, y, x], -60, 60))))
    dx, dy, w, h = geometry[:, y, x]
    center = np.array([x + np.clip(dx, 0, 1), y + np.clip(dy, 0, 1)]) / CELLS
    half = np.exp(np.clip([w, h], -6, 4)) / CELLS / 2
    return score, np.clip(np.r_[center - half, center + half], 0, 1)


def one_prediction(rgb, record, score, box):
    area = np.maximum(0, np.minimum(box[2:], record.boxes[:, 2:]) -
                      np.maximum(box[:2], record.boxes[:, :2])).prod(axis=1)
    union = (box[2:] - box[:2]).prod() + (record.boxes[:, 2:] - record.boxes[:, :2]).prod(axis=1) - area
    gray = ((rgb.astype(np.int32) @ np.array([77, 150, 29])) // 256) / 255
    return {"group": record.group, "image": record.path.name, "present": bool(len(record.boxes)),
            "iou": float((area / union).max()) if len(union) else 0,
            "quality": quality(gray), "score": score, "box": box.tolist()}


@torch.inference_mode()
def evaluate(model, views, device, tiled):
    model.eval()
    rows = []
    if tiled:
        starts = [(x, y) for y in TILE_STARTS for x in TILE_STARTS]
        for rgb, record in views:
            frames = np.stack([rgb[y:y+SIZE, x:x+SIZE] for x, y in starts])
            heatmap, geometry = model(tensor(frames, device))
            best = -1
            for (x, y), hm, g in zip(starts, heatmap.cpu().numpy(), geometry.cpu().numpy()):
                score, local = decode(hm, g)
                if score > best:
                    best, box = score, (local * SIZE + [x, y, x, y]) / TILE_GRID
            rows.append(one_prediction(rgb[::3, ::3], record, best, box))
        return rows
    for start in range(0, len(views), 12):
        batch = views[start:start+12]
        heatmap, geometry = model(tensor(np.stack([rgb for rgb, _ in batch]), device))
        rows.extend(one_prediction(rgb, record, *decode(hm, g))
                    for (rgb, record), hm, g in zip(batch, heatmap.cpu().numpy(), geometry.cpu().numpy()))
    return rows


def run(args):
    torch.manual_seed(SEED)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.deterministic = True
    torch.set_num_threads(3)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Training on {torch.cuda.get_device_name(device) if device.type == 'cuda' else 'CPU'}", flush=True)
    records, _, _ = read_export(args.data)
    views = {s: load_views([r for r in records if r.split == s], args.tiled)
             for s in ("train", "validation", "test")}
    rng = np.random.default_rng(SEED)
    model = CenterDetector().to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=.0015, weight_decay=.0001)
    schedule = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, args.epochs, eta_min=.00012)
    best = -1
    history = []
    for epoch in range(1, args.epochs + 1):
        model.train()
        total, steps = 0., 0
        indices = rng.permutation(np.tile(np.arange(len(views["train"])), 3 if args.tiled else 1))
        for start in range(0, len(indices), args.batch):
            examples = [augmented(views["train"][i][0], views["train"][i][1].boxes, rng, args.tiled)
                        for i in indices[start:start+args.batch]]
            frames = tensor(np.stack([rgb for rgb, _ in examples]), device)
            expected, geometry = zip(*(targets(boxes) for _, boxes in examples))
            prediction = model(frames)
            objective = loss(*prediction, torch.from_numpy(np.stack(expected)).to(device),
                             torch.from_numpy(np.stack(geometry)).to(device))
            optimizer.zero_grad(set_to_none=True)
            objective.backward()
            optimizer.step()
            total += objective.item()
            steps += 1
        schedule.step()
        if epoch % (4 if args.tiled else 2) == 0 or epoch == args.epochs:
            rows = evaluate(model, views["validation"], device, args.tiled)
            threshold = choose_threshold(rows)
            selected = metrics(rows, threshold)
            p, r = selected["precision_iou25"] or 0, selected["localized_positive_fraction"] or 0
            value = 1.25 * p * r / (.25 * p + r) if p and r else 0
            history.append({"epoch": epoch, "loss": total / steps, "validation_f_half": value,
                            "validation": selected, "threshold": threshold})
            if value > best:
                best, best_epoch = value, epoch
                checkpoint = {name: weight.detach().cpu().clone() for name, weight in model.state_dict().items()}
            print(f"epoch {epoch}: loss {total/steps:.3f}, validation F0.5 {value:.3f}, "
                  f"{selected['correct_iou25']}/{selected['shown']} localized", flush=True)
    model.load_state_dict(checkpoint)
    validation = evaluate(model, views["validation"], device, args.tiled)
    threshold = choose_threshold(validation)
    test = evaluate(model, views["test"], device, args.tiled)
    args.model.parent.mkdir(parents=True, exist_ok=True)
    model = model.cpu().eval()
    example = torch.zeros((1, 3, SIZE, SIZE))
    torch.onnx.export(model, example, str(args.model), input_names=["image"],
                      output_names=["heatmap", "geometry"], opset_version=17, dynamo=False)
    opts = onnxruntime.SessionOptions()
    opts.intra_op_num_threads = 2
    session = onnxruntime.InferenceSession(str(args.model), opts, providers=["CPUExecutionProvider"])
    parity_sample = tensor(views["validation"][0][0][None, :SIZE, :SIZE], "cpu")
    with torch.inference_mode():
        for portable, native in zip(session.run(None, {"image": parity_sample.numpy()}), model(parity_sample)):
            np.testing.assert_allclose(portable, native.numpy(), rtol=2e-3, atol=2e-4)
    digest = hashlib.sha256(args.model.read_bytes()).hexdigest()
    version = "hole-center-" + digest[:12]
    config = {
        "version": version, "sha256": digest, "grid": SIZE, "stride": STRIDE, "threshold": threshold,
        "input_grid": TILE_GRID if args.tiled else SIZE,
        "tile_starts": TILE_STARTS if args.tiled else [0],
        "source": json.loads((args.data / "source.json").read_text()),
    }
    write_json(args.model.with_suffix(".json"), config)
    report = {
        **config, "epochs": args.epochs, "best_epoch": best_epoch, "batch_size": args.batch,
        "device": torch.cuda.get_device_name(device) if device.type == "cuda" else "CPU",
        "parameters": sum(parameter.numel() for parameter in model.parameters()),
        "bytes": args.model.stat().st_size,
        "validation": metrics(validation, threshold), "test": {
            **metrics(test, threshold),
            "always_predict": metrics(test, 0, quality_gate=False),
            "threshold_only": metrics(test, threshold, quality_gate=False),
            "bootstrap_95": intervals(test, threshold),
        },
        "history": history,
    }
    write_json(args.report, report)
    write_json(args.model.with_name(args.model.stem + "_predictions.json"),
               {"validation": validation, "test": test})
    print("Held-out evaluation", json.dumps(report["test"], indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=Path(".data/holes"))
    parser.add_argument("--model", type=Path, default=Path(".data/neural/hole_center.onnx"))
    parser.add_argument("--report", type=Path, default=Path("research/experiments/neural_results.json"))
    parser.add_argument("--epochs", type=int, default=24)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--tiled", action="store_true")
    run(parser.parse_args())
