import 'dart:typed_data';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import '../models/app_errors.dart';

/// Service providing reusable image validation and decoding routines.
class ImageService {
  ImageService._();

  /// Maximum allowed image file size in bytes (28 MB).
  static const int maxFileSizeBytes = 28 * 1024 * 1024;

  /// Maximum supported pixel count (32 megapixels).
  static const int maxPixelCount = 32000000;

  /// Validates whether the given byte length conforms to the allowed size limit.
  ///
  /// Throws [ImageTooLargeError] if [sizeInBytes] exceeds [maxFileSizeBytes] or is empty.
  static void validateFileSize(int sizeInBytes) {
    if (sizeInBytes <= 0 || sizeInBytes > maxFileSizeBytes) {
      throw const ImageTooLargeError();
    }
  }

  /// Validates the file size of an [XFile].
  ///
  /// Throws [ImageTooLargeError] if the file size exceeds [maxFileSizeBytes].
  static Future<void> validateFile(XFile file) async {
    final length = await file.length();
    validateFileSize(length);
  }

  /// Validates the format and dimensions of encoded image [bytes].
  ///
  /// Throws [ImageTooLargeError] if file size exceeds [maxFileSizeBytes],
  /// or [ImageFormatError] if decoding fails or dimensions exceed [maxPixelCount].
  static void validateFormat(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxFileSizeBytes) {
      throw const ImageTooLargeError();
    }
    final decoder = image.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || (info.width * info.height) > maxPixelCount) {
      throw const ImageFormatError();
    }
  }

  /// Validates and decodes image [bytes] into an [image.Image].
  ///
  /// Checks file size and dimensions, bakes EXIF orientation, and normalizes
  /// channels to 3-channel uint8. Throws [ImageTooLargeError] or [ImageFormatError].
  static image.Image decodeAndValidate(Uint8List bytes) {
    validateFileSize(bytes.length);
    final decoder = image.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || (info.width * info.height) > maxPixelCount) {
      throw const ImageFormatError();
    }
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) {
      throw const ImageFormatError('Unable to decode image frame.');
    }
    return image
        .bakeOrientation(decoded)
        .convert(format: image.Format.uint8, numChannels: 3);
  }

  /// Checks if [sizeInBytes] is within valid bounds without throwing.
  static bool isValidSize(int sizeInBytes) =>
      sizeInBytes > 0 && sizeInBytes <= maxFileSizeBytes;
}
