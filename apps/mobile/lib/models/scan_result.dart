import 'dart:typed_data';
import 'dart:ui';

/// Represents the output of a vision inference scan on a textile image.
class Scan {
  /// Creates a new [Scan] result.
  const Scan(
    this.photo,
    this.status,
    this.model,
    this.elapsedMs, {
    this.box,
    this.score,
    this.focus,
  });

  /// The prepared JPEG image bytes associated with the scan.
  final Uint8List photo;

  /// The status result of the scan (e.g., 'candidate', 'uncertain', 'resolution', 'lighting', 'focus').
  final String status;

  /// The model version or identifier used during inference.
  final String model;

  /// The total time taken for preprocessing and inference, in milliseconds.
  final int elapsedMs;

  /// The detected bounding box normalized to [0, 1] relative coordinates, if a damage candidate was found.
  final Rect? box;

  /// The confidence score of the detection, normalized between 0 and 1, if available.
  final double? score;

  /// The normalized user focus point used to constrain the search, if specified.
  final Offset? focus;

  /// Serializes the scan result to a JSON-compatible map.
  Map<String, Object?> toJson() => {
    'status': status,
    'model': model,
    'elapsedMs': elapsedMs,
    'score': score,
    'box': box == null ? null : [box!.left, box!.top, box!.right, box!.bottom],
    if (focus != null) 'focus': [focus!.dx, focus!.dy],
  };
}
