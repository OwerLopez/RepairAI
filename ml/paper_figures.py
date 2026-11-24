"""Prepare risk–coverage and paired intervals for the pilot manuscript."""

import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter
import numpy as np

from experiment import IOU, SEED, metrics, write_json


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def paired_localization(a, b, a_threshold, b_threshold):
    before = {row["image"]: row for row in a}
    after = {row["image"]: row for row in b}
    if before.keys() != after.keys():
        raise ValueError("The two runs must evaluate the same views.")
    groups = {}
    for image, row in before.items():
        current = after[image]
        if current["group"] != row["group"]:
            raise ValueError(f"Mismatched garment for {image}")
        first = row["quality"] and row["score"] >= a_threshold and row["iou"] >= IOU
        second = current["quality"] and current["score"] >= b_threshold and current["iou"] >= IOU
        groups.setdefault(row["group"], []).append(int(second) - int(first))
    samples = list(groups.values())
    rng = np.random.default_rng(SEED)
    differences = [np.mean([value for i in rng.integers(len(samples), size=len(samples))
                            for value in samples[i]]) for _ in range(1000)]
    return {
        "views": len(before),
        "localized_positive_difference": sum(map(sum, samples)) / len(before),
        "bootstrap_95": np.percentile(differences, [2.5, 97.5]).tolist(),
    }


def figure(models, path, spanish=False):
    fig, ax = plt.subplots(figsize=(6.2, 3.45), layout="constrained")
    lines = [("#435f77", ":"), ("#886541", "--"), ("#785d8b", "-."), ("#33644d", "-")]
    for (name, entries), (color, style) in zip(models.items(), lines):
        thresholds = sorted({0, *(row["score"] for row in entries)}, reverse=True)
        stats = [metrics(entries, threshold, quality_gate=False) for threshold in thresholds]
        points = [(m["coverage"], 1 - m["precision_iou25"]) for m in stats if m["shown"]]
        ax.step(*np.array(points).T, where="post", label=name, color=color, linestyle=style, linewidth=2)
    ax.set(xlabel="Cobertura" if spanish else "Coverage",
           ylabel="Error entre propuestas mostradas" if spanish else "Localization error among shown views",
           xlim=(0, 1.03), ylim=(0, 1.035))
    ax.xaxis.set_major_formatter(PercentFormatter(1))
    ax.yaxis.set_major_formatter(PercentFormatter(1))
    ax.grid(alpha=.2)
    ax.legend(frameon=False, loc="lower right")
    fig.savefig(path, metadata={"Creator": "ReparaAI reproducibility pipeline"})
    plt.close(fig)


if __name__ == "__main__":
    data = Path(".data")
    research = Path("research")
    base = read(data / "heldout_predictions.json")
    full = data / "neural/hole_center_predictions.json"
    tiled = read(data / "neural/hole_tile_predictions.json")["test"]
    models = {"Logistic baseline": base["logistic"], "Random forest": base["forest"],
              "Whole-view CNN": read(full if full.exists() else data / "neural_predictions.json")["test"],
              "Tiled CNN": tiled}
    figure(models, research / "paper/figures/risk_coverage.pdf")
    spanish = dict(zip(("Regresión logística", "Bosque aleatorio", "CNN de vista completa", "CNN por mosaicos"),
                       models.values()))
    figure(spanish, research / "paper/figures/riesgo_cobertura.pdf", spanish=True)
    reports = research / "experiments"
    forest_threshold = read(reports / "vision_results.json")["thresholds"]["forest"]
    tile_threshold = read(reports / "tile_results.json")["threshold"]
    comparison = paired_localization(base["forest"], tiled, forest_threshold, tile_threshold)
    write_json(reports / "paired_comparison.json", comparison)
    print(json.dumps(comparison, indent=2))
