import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as image;

class Scan {
  const Scan(
    this.photo,
    this.status,
    this.model,
    this.elapsedMs, {
    this.box,
    this.score,
  });

  final Uint8List photo;
  final String status;
  final String model;
  final int elapsedMs;
  final Rect? box;
  final double? score;

  Map<String, Object?> toJson() => {
    'status': status,
    'model': model,
    'elapsedMs': elapsedMs,
    'score': score,
    'box': box == null ? null : [box!.left, box!.top, box!.right, box!.bottom],
  };
}

typedef _Frame = ({Uint8List photo, String? rejected, Uint8List? rgb});

class Vision {
  Vision(Map<String, dynamic> model)
    : version = model['version'] as String,
      grid = model['grid'] as int,
      stride = model['stride'] as int,
      inputGrid = model['input_grid'] as int,
      starts = (model['tile_starts'] as List).cast<int>(),
      threshold = (model['threshold'] as num).toDouble();

  final String version;
  final int grid;
  final int stride;
  final int inputGrid;
  final List<int> starts;
  final double threshold;

  Future<Scan> scan(Uint8List bytes) async {
    final timer = Stopwatch()..start();
    final frame = await compute(_prepareFrame, (
      bytes: bytes,
      grid: grid,
      inputGrid: inputGrid,
    ));
    if (frame.rejected case final reason?) {
      return Scan(frame.photo, reason, version, timer.elapsedMilliseconds);
    }
    final session = await OnnxRuntime().createSessionFromAsset(
      'assets/hole_tile.onnx',
      options: OrtSessionOptions(intraOpNumThreads: 2),
    );
    try {
      double best = -double.infinity;
      Rect? box;
      for (final y in starts) {
        for (final x in starts) {
          final result = await _tile(session, frame.rgb!, x, y);
          if (result.score > best) {
            best = result.score;
            box = result.box;
          }
        }
      }
      return Scan(
        frame.photo,
        best >= threshold ? 'candidate' : 'uncertain',
        version,
        timer.elapsedMilliseconds,
        score: best,
        box: best >= threshold ? box : null,
      );
    } finally {
      await session.close();
    }
  }

  Future<({double score, Rect box})> _tile(
    OrtSession session,
    Uint8List rgb,
    int x,
    int y,
  ) async {
    final area = grid * grid;
    final pixels = Float32List(area * 3);
    for (var row = 0; row < grid; row++) {
      for (var column = 0; column < grid; column++) {
        final input = ((y + row) * inputGrid + x + column) * 3;
        final output = row * grid + column;
        pixels[output] = rgb[input] / 255;
        pixels[area + output] = rgb[input + 1] / 255;
        pixels[area * 2 + output] = rgb[input + 2] / 255;
      }
    }
    final tensor = await OrtValue.fromList(pixels, [1, 3, grid, grid]);
    final outputs = <String, OrtValue>{};
    try {
      outputs.addAll(await session.run({'image': tensor}));
      final heat = (await outputs['heatmap']!.asFlattenedList()).cast<num>();
      final geometry = (await outputs['geometry']!.asFlattenedList())
          .cast<num>();
      final cells = grid ~/ stride;
      final index = Iterable<int>.generate(
        heat.length,
      ).reduce((a, b) => heat[a] >= heat[b] ? a : b);
      final centerX = (index % cells + geometry[index].clamp(0, 1)) / cells;
      final centerY =
          (index ~/ cells + geometry[heat.length + index].clamp(0, 1)) / cells;
      final width =
          math.exp(geometry[heat.length * 2 + index].clamp(-6, 4)) / cells / 2;
      final height =
          math.exp(geometry[heat.length * 3 + index].clamp(-6, 4)) / cells / 2;
      double map(double local, int start) =>
          (local.clamp(0, 1) * grid + start) / inputGrid;
      return (
        score: 1 / (1 + math.exp(-heat[index].clamp(-60, 60))),
        box: Rect.fromLTRB(
          map(centerX - width, x),
          map(centerY - height, y),
          map(centerX + width, x),
          map(centerY + height, y),
        ),
      );
    } finally {
      await Future.wait([
        tensor.dispose(),
        for (final value in outputs.values) value.dispose(),
      ]);
    }
  }

  static Future<Uint8List> preparePhoto(Uint8List bytes) =>
      compute((data) => _displayPhoto(_decode(data)), bytes);
}

_Frame _prepareFrame(({Uint8List bytes, int grid, int inputGrid}) input) {
  final image = _decode(input.bytes);
  final photo = _displayPhoto(image);
  final n = input.grid;
  if (math.min(image.width, image.height) < n) {
    return (photo: photo, rejected: 'resolution', rgb: null);
  }
  final pixels = Float64List(n * n);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final p = image.getPixel(x * image.width ~/ n, y * image.height ~/ n);
      pixels[y * n + x] = (77 * p.r + 150 * p.g + 29 * p.b) ~/ 256 / 255;
    }
  }
  final mean = pixels.reduce((a, b) => a + b) / pixels.length;
  if (mean < .07 || mean > .96) {
    return (photo: photo, rejected: 'lighting', rgb: null);
  }
  var focus = 0.0;
  for (var y = 1; y < n - 1; y++) {
    for (var x = 1; x < n - 1; x++) {
      final i = y * n + x;
      final laplacian =
          -4 * pixels[i] +
          pixels[i + n] +
          pixels[i - n] +
          pixels[i + 1] +
          pixels[i - 1];
      focus += laplacian * laplacian;
    }
  }
  if (focus / ((n - 2) * (n - 2)) < .00012) {
    return (photo: photo, rejected: 'focus', rgb: null);
  }
  final samples = input.inputGrid;
  final rgb = Uint8List(samples * samples * 3);
  for (var y = 0; y < samples; y++) {
    for (var x = 0; x < samples; x++) {
      final p = image.getPixel(
        x * image.width ~/ samples,
        y * image.height ~/ samples,
      );
      final index = (y * samples + x) * 3;
      rgb[index] = p.r.toInt();
      rgb[index + 1] = p.g.toInt();
      rgb[index + 2] = p.b.toInt();
    }
  }
  return (photo: photo, rejected: null, rgb: rgb);
}

image.Image _decode(Uint8List data) {
  if (data.isEmpty || data.length > 28 * 1024 * 1024) {
    throw const FormatException('Image size');
  }
  final decoder = image.findDecoderForData(data);
  final info = decoder?.startDecode(data);
  if (info == null || info.width * info.height > 32000000) {
    throw const FormatException('Image format or dimensions');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('Image data');
  return image
      .bakeOrientation(decoded)
      .convert(format: image.Format.uint8, numChannels: 3);
}

Uint8List _displayPhoto(image.Image original) {
  final landscape = original.width >= original.height;
  image.Image resize(image.Image source, int limit) => image.copyResize(
    source,
    width: landscape ? limit : null,
    height: landscape ? null : limit,
    interpolation: image.Interpolation.average,
  );
  final photo = math.max(original.width, original.height) > 1280
      ? resize(original, 1280)
      : original;
  final clean = image.Image.fromBytes(
    width: photo.width,
    height: photo.height,
    bytes: photo.getBytes().buffer,
    numChannels: 3,
  );
  for (final quality in [78, 60, 40]) {
    final jpeg = image.encodeJpg(clean, quality: quality);
    if (jpeg.length <= 450000) return jpeg;
  }
  return image.encodeJpg(resize(clean, 640), quality: 55);
}
