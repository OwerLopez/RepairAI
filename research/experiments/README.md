# Reproducing the UCRA pilot

The classical and neural results are computed on the same garment-grouped splits. The test cohort contains only positive views. For each view we report the one highest-scoring location, which is distinct from reporting instance-level AP. Evaluation JSON and figures are tracked. Training photos and intermediate run files stay in `.data/`.

```sh
python -m venv .venv
# Activate this environment in your shell before running the next commands.
python -m pip install -r ml/requirements.txt
python ml/acquire.py
python ml/experiment.py
python -m pip install -r ml/requirements-neural.txt
python ml/neural.py
python ml/neural.py --tiled --epochs 24 --batch 24 \
  --model .data/neural/hole_tile.onnx --report research/experiments/tile_results.json
python ml/paper_tables.py
python ml/paper_figures.py
```

For the recorded NVIDIA run, the PyTorch wheel was installed with `python -m pip install torch==2.8.0 --index-url https://download.pytorch.org/whl/cu128` before installing the neural requirements. The ONNX export is checked against PyTorch on a validation tensor. Numerical results and exported bytes can vary with hardware and backend versions. The exact deployed binary and metadata are in `apps/mobile/assets`. Its SHA-256 is recorded in `hole_tile.json` and verified in CI.

Files `vision_results.json`, `neural_results.json` and `tile_results.json` record model selection, thresholds, operating-point metrics, ablations and 95% bootstrap intervals. The training script records the checkpoint hash and writes per-image predictions and split membership in the ignored data directory. The manuscript labels the tiled experiment exploratory because it was motivated by baseline failures.
