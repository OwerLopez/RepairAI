# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.0] - 2026-11-23

### Added
- **On-Device Vision & Screening Pipeline**:
  - Sliding-window tile inference engine using Microsoft ONNX Runtime (`flutter_onnxruntime`) executing `assets/hole_tile.onnx`.
  - Tiled sliding-window execution across an 1152x1152 input grid with 384x384 windows, stride 4, and offset starts `[0, 256, 512, 768]`.
  - Sigmoid center-heatmap prediction and 4-channel bounding box geometry regression for textile hole localization.
  - Model abstention mechanism returning status `'uncertain'` when detection confidence is below the 0.35 threshold.
  - Pre-inference quality gating in a background isolate (`compute()`):
    - Minimum resolution gate rejecting inputs under 384px along any dimension (`'resolution'`).
    - Normalized grayscale luminance check rejecting underexposed (< 0.07) or overexposed (> 0.96) frames (`'lighting'`).
    - Discrete 2D 4-point Laplacian kernel edge variance check rejecting blurred images under 0.00012 variance (`'focus'`).
  - Interactive focal refinement ("Señalar zona") allowing users to constrain tile evaluation to a 20% spatial bounding box around a tapped location.

- **Human-in-the-Loop Diagnosis**:
  - Interactive diagnosis screen (`DiagnosisPage`) displaying detected candidate bounding box and confidence score.
  - Structured user confirmation form verifying damage category (`hole`, `seam`, `tear`), fabric type (`denim`, `woven`), and sewing machine availability.
  - Clear user disclosure distinguishing advisory AI suggestions from confirmed user observations.

- **Knowledge Retrieval & Repair Procedures**:
  - Curated, versioned textile repair procedure catalog (`assets/procedures.json`, version `textile-guides-1`).
  - Structured step-by-step guides citing verified public authorities:
    - *iFixit*: How to Darn a Hole in Denim Jeans by Hand (`denim-darn`).
    - *Patagonia / iFixit*: Blanket Stitch on a Patch (`woven-patch`).
    - *Patagonia / iFixit*: Repair a Torn Seam (`straight-seam`).
    - *Patagonia / iFixit*: Baseball Stitch on a Tear (`woven-tear`).
  - Deterministic specificity ranking algorithm prioritizing procedures with narrower fabric scope over generalized guides.
  - Direct HTTPS source verification launching canonical documentation in the system browser.

- **Guided Repair & Session Journal**:
  - Step-by-step repair execution interface (`RepairPage`) with sequential checklist progression.
  - Local-first relational database persistence via SQLite (`Journal`), storing active session states, diagnostic metadata, full plan snapshots, and photo evidence.
  - Idempotent step advancement preventing concurrent update race conditions.
  - After-repair evidence photo capture with comparative visual inspection against the initial damage photo.
  - Final repair outcome declaration with status logging (`'repaired'`, `'partial'`, `'stopped'`) and custom user reflection notes.
  - Session history list with resume support and complete atomic session deletion.

- **Privacy & Local-First Security**:
  - Strict offline-first operation requiring no cloud backend, accounts, or network connectivity; 100% operational in airplane mode.
  - Image sanitization pipeline stripping all EXIF metadata (including GPS coordinates, timestamp, and camera hardware tags) prior to persistence.
  - Automated EXIF orientation baking (`image.bakeOrientation()`).
  - Multi-tier progressive JPEG compression (qualities 78 -> 60 -> 40 targeting <= 450 KB, fallback resize to 640px) to prevent SQLite cursor window exhaustion.
  - Explicit disabling of Android Auto Backup (`android:allowBackup="false"`) to protect private user photographs from remote cloud sync.

- **UI & Accessibility**:
  - Modern "Aurora & Frosted Glass" design system (`GlassBackdrop`, `_Aurora` custom shader with radial glows, and `GlassCard`).
  - High-contrast, low-light color palette optimized for workshop environments.
  - Dynamic runtime bilingual localization (Spanish default, English supported) with persistent locale preference storage.
  - Android activity recreation recovery using `ImagePicker.retrieveLostData()` to restore camera photos after low-memory lifecycle kills.

- **Cross-Platform & Deployment**:
  - Android support from Android 7.0 (API 24) to Android 16 (API 36).
  - 16 KB ELF page alignment configuration (`PAGE_ALIGNMENT_16K`) compliant with Android 15/16 memory standards.
  - ABI-split APK packaging (`arm64-v8a`, `x86_64`) and signed App Bundle (AAB) support.
  - Web application deployment to GitHub Pages using WebAssembly SQLite (`sqlite3.wasm` 2.9.4 with service worker) and ONNX Runtime Web.

- **Testing & Continuous Integration**:
  - Unit test suite covering procedure retrieval specificity and image quality/EXIF stripping (`apps/mobile/test/`).
  - End-to-end automated ADB smoke test suite (`scripts/android_smoke.py`) testing the full lifecycle on Android emulators in airplane mode.
  - GitHub Actions CI pipeline (`.github/workflows/pilot.yml`) verifying paper tables, ONNX asset hash integrity, Dart format, Flutter analyze, Flutter test, and APK builds.
  - GitHub Actions deployment pipeline (`.github/workflows/pages.yml`) automating static web publishing.
