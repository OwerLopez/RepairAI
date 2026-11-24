"""Train CPU baselines and export a versioned, offline mobile detector."""

import argparse
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

from vision import BOXES, GRID, SCALES, features, grayscale, overlaps, quality, read_export


SEED = 104
IOU = .25


def write_json(path, obj, compact=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=None if compact else 2, separators=(",", ":") if compact else None)
                    + "\n", encoding="utf-8")


def targets(record):
    if len(record.boxes) == 0:
        return np.zeros(len(BOXES))
    return overlaps(BOXES, record.boxes).max(axis=1)


def train(records):
    rng = np.random.default_rng(SEED)
    samples, labels = [], []
    for record in records:
        match = targets(record)
        positive = np.flatnonzero(match >= IOU)
        negative = np.flatnonzero(match < .05)
        if len(positive) > 128:
            positive = rng.choice(positive, 128, replace=False)
        negative = rng.choice(negative, min(len(negative), max(96, 5 * len(positive))), replace=False)
        chosen = np.concatenate((positive, negative))
        from vision import WINDOWS
        samples.append(features(grayscale(record.path), WINDOWS[chosen]))
        labels.append(match[chosen] >= IOU)
    x, y = np.concatenate(samples), np.concatenate(labels)
    models = {
        "logistic": make_pipeline(StandardScaler(), LogisticRegression(class_weight="balanced", random_state=SEED)),
        "forest": RandomForestClassifier(n_estimators=32, max_depth=10, min_samples_leaf=12,
                                         class_weight="balanced_subsample", random_state=SEED, n_jobs=6),
    }
    for model in models.values():
        model.fit(x, y)
    return models, {"windows": len(x), "positive_windows": int(y.sum())}


def evaluate(models, records):
    rows = {name: [] for name in models}
    for record in records:
        gray = grayscale(record.path)
        x, match = features(gray), targets(record)
        for name, model in models.items():
            scores = model.predict_proba(x)[:, 1]
            index = int(np.argmax(scores))
            rows[name].append({
                "group": record.group, "image": record.path.name,
                "present": bool(len(record.boxes)), "quality": quality(gray),
                "score": float(scores[index]), "iou": float(match[index]), "box": BOXES[index].tolist(),
            })
    return rows


def metrics(rows, threshold, quality_gate=True):
    accepted = [r for r in rows if r["score"] >= threshold and (r["quality"] or not quality_gate)]
    correct = sum(r["iou"] >= IOU for r in accepted)
    positive = sum(r["present"] for r in rows)
    return {
        "views": len(rows), "positive_views": positive, "shown": len(accepted), "correct_iou25": correct,
        "correct_iou50": sum(r["iou"] >= .5 for r in accepted),
        "coverage": len(accepted) / len(rows),
        "precision_iou25": correct / len(accepted) if accepted else None,
        "localized_positive_fraction": correct / positive if positive else None,
    }


def choose_threshold(rows):
    options = []
    for threshold in np.arange(.0, 1.001, .025):
        m = metrics(rows, threshold)
        precision = m["precision_iou25"] or 0
        recall = m["localized_positive_fraction"] or 0
        f_half = 1.25 * precision * recall / (.25 * precision + recall) if precision + recall else 0
        options.append((f_half, float(threshold)))
    return max(options)[1]


def intervals(rows, threshold):
    by_group = {}
    for row in rows:
        by_group.setdefault(row["group"], []).append(row)
    groups = list(by_group.values())
    rng = np.random.default_rng(SEED)
    results = [metrics([row for i in rng.integers(len(groups), size=len(groups)) for row in groups[i]], threshold)
               for _ in range(1000)]
    keys = ("coverage", "precision_iou25", "localized_positive_fraction")
    return {key: np.percentile(values, [2.5, 97.5]).tolist() if values else None
            for key in keys if (values := [m[key] for m in results if m[key] is not None]) or results}


def plot(rows, path):
    fig, ax = plt.subplots(figsize=(6, 3.3), layout="constrained")
    for label, data in rows.items():
        stats = [metrics(data, t, quality_gate=False) for t in np.arange(0, 1.001, .005)]
        points = [(m["coverage"], 1 - m["precision_iou25"]) for m in stats if m["shown"]]
        ax.plot(*np.array(points).T, label=label.capitalize())
    ax.set(xlabel="Coverage (all held-out views)", ylabel="Localization error among shown views",
           xlim=(0, 1.02), ylim=(0, 1.02))
    ax.grid(alpha=.2)
    ax.legend(frameon=False)
    fig.savefig(path, metadata={"Creator": "ReparaAI reproducibility pipeline"})
    plt.close(fig)


def export(model, threshold, source, path):
    trees = []
    for estimator in model.estimators_:
        tree = estimator.tree_
        trees.append([tree.children_left.tolist(), tree.children_right.tolist(), tree.feature.tolist(),
                      tree.threshold.tolist(), tree.value[:, 0, 1].tolist()])
    model_data = {"grid": GRID, "scales": SCALES, "threshold": threshold, "source": source, "trees": trees}
    digest = hashlib.sha256(json.dumps(model_data, sort_keys=True).encode()).hexdigest()
    model_data["version"] = "hole-rf-" + digest[:12]
    write_json(path, model_data, compact=True)
    return model_data["version"]


def main(args):
    source = json.loads((args.data / "source.json").read_text())
    records, exports, overlap = read_export(args.data)
    if exports != source["counts"]["train/images"] + source["counts"]["valid/images"]:
        raise ValueError("Local image count does not match pinned export")
    splits = {split: [record for record in records if record.split == split]
              for split in ("train", "validation", "test")}
    if any(not split for split in splits.values()):
        raise ValueError("All grouped splits must have data.")
    print("Split sizes", {split: len(rows) for split, rows in splits.items()}, flush=True)
    with threadpool_limits(limits=1):
        models, training = train(splits["train"])
        print("Training finished", training, flush=True)
        validation = evaluate(models, splits["validation"])
        thresholds = {name: choose_threshold(rows) for name, rows in validation.items()}
        test = evaluate(models, splits["test"])
    args.figure.parent.mkdir(parents=True, exist_ok=True)
    plot(test, args.figure)
    version = export(models["forest"], thresholds["forest"], source, args.model)
    summary = {
        "dataset": source,
        "exports": exports, "upstream_groups_in_both_splits": overlap,
        "splits": {split: {
            "views": len(rows), "groups": len({r.group for r in rows}),
            "positive_views": sum(bool(len(r.boxes)) for r in rows),
            "boxes": sum(len(r.boxes) for r in rows),
        } for split, rows in splits.items()},
        "original_sizes": sorted({r.original_size for r in records}),
        "training": training, "model_version": version, "thresholds": thresholds,
        "validation": {name: metrics(rows, thresholds[name]) for name, rows in validation.items()},
        "test": {name: {
            **metrics(rows, thresholds[name]),
            "always_predict": metrics(rows, 0, quality_gate=False),
            "threshold_only": metrics(rows, thresholds[name], quality_gate=False),
            "image_presence_ap": float(average_precision_score([r["present"] for r in rows], [r["score"] for r in rows])),
            "bootstrap_95": intervals(rows, thresholds[name]),
            "quality_rejected": sum(not r["quality"] for r in rows),
        } for name, rows in test.items()},
    }
    write_json(args.report, summary)
    write_json(args.data.parent / "heldout_predictions.json", test)
    write_json(args.data.parent / "split_manifest.json", [
        {"image": r.path.name, "group": r.group, "split": r.split} for r in records])
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=Path(".data/holes"))
    parser.add_argument("--model", type=Path, default=Path("apps/mobile/assets/hole_model.json"))
    parser.add_argument("--report", type=Path, default=Path("research/experiments/vision_results.json"))
    parser.add_argument("--figure", type=Path, default=Path("research/paper/figures/risk_coverage.pdf"))
    main(parser.parse_args())
