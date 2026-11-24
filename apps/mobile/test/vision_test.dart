import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reparaai/vision.dart';

void main() {
  final vision = Vision(
    jsonDecode(File('assets/hole_tile.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  test('rejects invalid input before scoring', () async {
    await expectLater(
      vision.scan(img.encodeJpg(img.Image(width: 24, height: 24))),
      completion(
        isA<Scan>().having((scan) => scan.status, 'status', 'resolution'),
      ),
    );
    await expectLater(
      vision.scan(img.encodeJpg(img.Image(width: 400, height: 400))),
      completion(
        isA<Scan>().having((scan) => scan.status, 'status', 'lighting'),
      ),
    );
  });

  test('strips location metadata from evidence copies', () async {
    final original = img.Image(width: 500, height: 500);
    original.exif.gpsIfd[1] = 'N';
    final copy = await Vision.preparePhoto(img.encodeJpg(original));
    final decoded = img.decodeJpg(copy)!;
    expect(decoded.width, 500);
    expect(decoded.exif.gpsIfd[1], isNull);
  });
}
