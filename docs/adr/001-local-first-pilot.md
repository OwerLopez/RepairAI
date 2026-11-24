# ADR 001 · Offline Android pilot

**Accepted 23 November 2026.**

## Context

The first deliverable must exercise the photo-to-repair journey while the textile evidence is collected. The garment dataset provides spatial supervision and consists entirely of views with a labeled hole. The detected area and a user's report therefore carry distinct evidence.

## Decision

Flutter provides the Android app and an iOS project. A native ONNX Runtime plugin executes the tiled center-heatmap model on device. The versioned intervention catalog assembles a plan by filtering damage, materials and tool availability. SQLite stores each plan snapshot, model output, user-observed damage, step progression, compressed images and final report. Sessions can be resumed offline. Images are oriented and stored without EXIF and Android backup is disabled for the app.

The pilot requires no account or remote service to repair a garment. Public links offer access to the full source procedures. Accounts, cross-device synchronization, centralized administration and server-side generation require a separate data and consent design. Flutter runs on Android in the tested configuration. iOS builds require Xcode verification.
