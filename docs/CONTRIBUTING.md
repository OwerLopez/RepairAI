# Contributing to ReparaAI

Thank you for your interest in contributing to **ReparaAI**! Whether you are fixing a bug, expanding our textile repair knowledge base, improving on-device machine learning models, or refining the Flutter user interface, your contributions are welcome.

ReparaAI is built on principles of **local-first edge computing**, **user privacy**, and **open accessibility**. We expect all contributions to align with these foundational standards.

---

## 1. Prerequisites

Before setting up the project locally, verify that your workstation satisfies the following software toolchain requirements:

| Component | Required Version | Verification Command | Notes |
| :--- | :--- | :--- | :--- |
| **Flutter SDK** | `3.38.3` (channel stable) | `flutter --version` | Framework used for mobile and web builds. |
| **Dart SDK** | `^3.10.1` | `dart --version` | Included with Flutter SDK 3.38.3. |
| **Java Development Kit** | JDK 17 or JDK 21 | `java -version` | Recommended: Eclipse Temurin or OpenJDK. Required for Android Gradle builds. |
| **Android SDK** | API Level 36 (compile/target) | `sdkmanager --list` | Android SDK Platform 36, Build-Tools, and Platform-Tools. |
| **Android Emulator / Device** | Android 7.0+ (API 24+) | `adb devices` | Required for on-device testing and integration smoke tests. |
| **Python** | 3.12+ | `python --version` | Required for ML training pipelines, paper verification, and ADB automation. |
| **Git** | 2.30+ | `git --version` | Version control. |

> [!NOTE]
> Run `flutter doctor -v` after installing Flutter and the Android SDK to ensure all licenses are accepted and dependencies are discovered.

---

## 2. Workspace Setup

### 2.1 Clone the Repository

Clone the project repository to your local machine:

```bash
git clone https://github.com/OwerLopez/RepairAI.git
cd RepairAI
```

### 2.2 Install Mobile Dependencies

Navigate into the Flutter application directory and install packages using the enforced lockfile:

```bash
cd apps/mobile
flutter pub get --enforce-lockfile
```

### 2.3 Set Up Python Environment (Optional for Research / Automation)

If you plan to work on the machine learning pipeline (`ml/`), run integration smoke tests (`scripts/`), or reproduce research experiments (`research/`):

```bash
# Return to repository root
cd ../..

# Create and activate virtual environment
python -m venv .venv

# On Linux/macOS:
source .venv/bin/activate

# On Windows PowerShell:
.\.venv\Scripts\Activate.ps1

# Install requirements if testing ML scripts
pip install -r ml/requirements.txt # if applicable
```

### 2.4 Run the Application Locally

Verify your connected physical device, running Android emulator, or browser:

```bash
cd apps/mobile
flutter devices
```

Launch the app in debug mode:

```bash
# Launch on an Android device or emulator
flutter run -d <DEVICE_ID>

# Launch on Chrome (web mode)
flutter run -d chrome
```

---

## 3. Project Structure

ReparaAI is organized as a modular repository separating the client application, machine learning assets, scientific research artifacts, and integration tooling:

```
RepairAI/
├── .github/
│   ├── ISSUE_TEMPLATE/       # GitHub issue and feature templates
│   └── workflows/            # GitHub Actions CI/CD (pilot.yml, pages.yml)
├── apps/
│   └── mobile/               # Main Flutter application
│       ├── android/          # Android platform configuration, Gradle scripts
│       ├── assets/           # Bundled assets (hole_tile.onnx, hole_tile.json, procedures.json)
│       ├── lib/              # Dart application source code
│       │   ├── diagnosis_page.dart # Interactive diagnosis and candidate inspection
│       │   ├── glass.dart          # Frosted glass styling and Aurora custom painter
│       │   ├── home.dart           # Dashboard, capture triggers, session list
│       │   ├── journal.dart        # SQLite repository and preferences
│       │   ├── main.dart           # App entry point, bootstrap, theme setup
│       │   ├── procedures.dart     # Repair procedures catalog & matching engine
│       │   ├── repair_page.dart    # Guided repair checklist, evidence, outcome
│       │   ├── ui.dart             # Shared UI widgets and localization helpers
│       │   └── vision.dart         # Vision engine, quality heuristics, ONNX inference
│       ├── test/             # Unit and widget test suite
│       ├── web/              # Web shell, sqlite3.wasm, WebAssembly worker
│       └── pubspec.yaml      # Dependencies and Flutter asset configurations
├── docs/                     # Technical documentation
│   ├── adr/                  # Architectural Decision Records (ADRs)
│   ├── API.md                # Internal API specifications
│   ├── ARCHITECTURE.md       # Comprehensive system architecture document
│   ├── CONTRIBUTING.md       # Contribution guidelines
│   ├── PLAY_STORE.md         # Play Console release and signing instructions
│   ├── PRIVACIDAD.md         # Data privacy and local-first compliance notes
│   ├── PROJECT_STATUS.md     # Module implementation status matrix
│   └── TESTING.md            # Quality assurance and testing protocol
├── ml/                       # Machine learning data acquisition, training, ONNX export
├── research/                 # IEEE paper LaTeX source, dataset records, experimental results
├── scripts/                  # ADB automation and smoke test scripts
├── CHANGELOG.md              # Project version history (Keep a Changelog format)
└── README.md                 # Project landing page and overview
```

---

## 4. Code Style & Quality Standards

All Dart code submitted to ReparaAI must adhere strictly to repository formatting and static analysis rules.

### 4.1 Mandatory Code Formatting

Every file must be formatted using the standard Dart formatter. Verify formatting across `lib` and `test`:

```bash
cd apps/mobile
dart format --output=none --set-exit-if-changed lib test
```

To automatically format all files in-place:

```bash
dart format lib test
```

### 4.2 Static Code Analysis

Code must pass the Flutter analyzer without errors or warnings according to `analysis_options.yaml` (utilizing `package:flutter_lints`):

```bash
cd apps/mobile
flutter analyze --no-pub
```

### 4.3 Engineering Guidelines

- **Null Safety**: All Dart code must be soundly null-safe. Avoid force unwrap operators (`!`) unless accompanied by an explicit null check or invariant guarantee.
- **Isolate Offloading**: CPU-intensive operations (image transformations, pixel convolutions, large JSON processing) must run inside worker isolates using `compute()`.
- **Resource Disposal**: Always dispose of database handles, controllers, `OrtValue` tensors, and ONNX sessions within `finally` blocks or state `dispose()` methods.
- **Bilingual Strings**: User-facing copy must never be hardcoded in a single language. Use the `BuildContext` extension helper:
  ```dart
  context.t('Texto en español', 'Text in English')
  ```
- **Privacy by Design**: Never introduce analytics SDKs, network telemetry, or third-party tracking scripts. Ensure all captured images are stripped of EXIF metadata before persistence.

---

## 5. Testing Protocol

All pull requests must pass automated checks before review.

### 5.1 Unit Tests

Execute the Flutter unit test suite from `apps/mobile`:

```bash
cd apps/mobile
flutter test --no-pub
```

Ensure new functionality is covered by corresponding tests in `apps/mobile/test/`:
- `procedures_test.dart`: Validates repair procedure filtering, tool requirements, and specificity ranking.
- `vision_test.dart`: Validates quality gate rejection (resolution, lighting, focus) and EXIF metadata stripping.

### 5.2 Build Verification

Ensure the Android APK compiles cleanly across ABI targets:

```bash
cd apps/mobile
flutter build apk --debug --target-platform android-arm64,android-x64 --split-per-abi --no-pub
```

### 5.3 Automated Integration Smoke Test (Android via ADB)

ReparaAI features an end-to-end integration test (`scripts/android_smoke.py`) that executes on an Android emulator or connected device via ADB. It validates:
1. Native gallery interaction and image ingestion.
2. Quality checks and on-device ONNX model inference in Airplane Mode.
3. Locale switching between Spanish and English.
4. Process termination and session resumption from SQLite.
5. Step checklist completion, photo evidence capture, and outcome finalization.

To run the smoke test:

```bash
# Ensure an Android emulator or device is online
adb devices

# Run the automated smoke test script
python scripts/android_smoke.py \
  --serial emulator-5554 \
  --apk apps/mobile/build/app/outputs/flutter-apk/app-x86_64-debug.apk \
  --photo .data/diagnosis.png \
  --report output/smoke_report.json \
  --screenshots .data/smoke-screens
```

---

## 6. Pull Request (PR) Workflow

Follow this step-by-step workflow when submitting changes:

```
[Create Feature Branch] ──> [Commit with Conventional Commits] ──> [Run Local Quality Checks]
                                                                            │
[Merge into main] <── [Peer Review & CI Approval] <── [Open Pull Request] <─┘
```

### 6.1 Branch Naming Convention

Create a focused topic branch branched from `main`:
- `feature/<short-description>` (e.g., `feature/knit-procedure`)
- `fix/<issue-number>-<short-description>` (e.g., `fix/104-exif-stripping`)
- `docs/<short-description>` (e.g., `docs/architecture-update`)
- `research/<experiment-name>` (e.g., `research/ablation-stride`)

### 6.2 Commit Message Guidelines

Use the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`
- **Scopes**: `vision`, `journal`, `knowledge`, `ui`, `android`, `web`, `ml`, `docs`
- **Example**: `feat(knowledge): add wool mending procedure with blanket stitch`

### 6.3 Pre-Submission Checklist

Before pushing your changes, run this one-line verification command in `apps/mobile`:

```bash
dart format --output=none --set-exit-if-changed lib test && flutter analyze --no-pub && flutter test --no-pub
```

### 6.4 Opening the PR

1. Push your branch to your fork on GitHub.
2. Open a Pull Request targeting the `main` branch.
3. Fill out the PR template completely:
   - Provide a clear summary of the problem and your solution.
   - Link related issue numbers (e.g., `Closes #42`).
   - Include before/after screenshots for any UI alterations.
   - Note any performance or memory considerations.
4. Verify that all automated GitHub Actions checks (`Pilot validation`) pass.
5. Respond constructively to code review feedback.
