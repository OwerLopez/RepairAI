/// Base exception class for all ReparaAI application errors.
abstract class AppError implements Exception {
  /// Creates an [AppError] with a descriptive [message].
  const AppError(this.message);

  /// The human-readable error description.
  final String message;

  @override
  String toString() => message;
}

/// Thrown when an image file exceeds the maximum allowed file size.
class ImageTooLargeError extends AppError implements FormatException {
  /// Creates an [ImageTooLargeError] with a descriptive message.
  const ImageTooLargeError([
    super.message =
        'The selected image exceeds the maximum size limit of 28 MB.',
  ]);

  @override
  dynamic get source => null;

  @override
  int? get offset => null;
}

/// Thrown when an image has an invalid format, corrupted data, or unsupported dimensions.
class ImageFormatError extends AppError implements FormatException {
  /// Creates an [ImageFormatError] with a descriptive message.
  const ImageFormatError([
    super.message =
        'The image format or dimensions are invalid or unsupported.',
  ]);

  @override
  dynamic get source => null;

  @override
  int? get offset => null;
}

/// Thrown when a database read, write, or transaction error occurs.
class DatabaseError extends AppError {
  /// Creates a [DatabaseError] with a descriptive message and optional root [cause].
  const DatabaseError([
    super.message = 'A database operation failed.',
    this.cause,
  ]);

  /// The underlying exception or error that caused this failure, if available.
  final Object? cause;

  @override
  String toString() => cause != null ? '$message: $cause' : message;
}
