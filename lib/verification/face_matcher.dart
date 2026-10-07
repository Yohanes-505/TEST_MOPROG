import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// ubah foto jadi embedding lalu bandingin dengan cosine similarity
class FaceMatcher {
  FaceMatcher._();
  static final instance = FaceMatcher._();

  static const _modelAsset = 'assets/models/mobile_face_net.tflite';
  Interpreter? _interpreter;

  Future<Interpreter> _load() async =>
      _interpreter ??= await Interpreter.fromAsset(_modelAsset);

  /// return embedding ternormalisasi L2 ato null kalau wajah tidak ketemu
  Future<List<double>?> embed(File file) async {
    final interpreter = await _load();

    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) return null;
    final baked = img.bakeOrientation(decoded);

    // simpan versi yang sudah diputar benar supaya koordinat ML Kit konsisten
    final tmp = File(
        '${Directory.systemTemp.path}/fm_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await tmp.writeAsBytes(img.encodeJpg(baked, quality: 92));

    final detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
    );
    List<Face> faces;
    try {
      faces = await detector.processImage(InputImage.fromFilePath(tmp.path));
    } finally {
      await detector.close();
      if (await tmp.exists()) await tmp.delete();
    }
    if (faces.isEmpty) return null;

    faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
        .compareTo(a.boundingBox.width * a.boundingBox.height));
    final box = faces.first.boundingBox;

    final pad = box.width * 0.1;
    final x = math.max(0, (box.left - pad).floor());
    final y = math.max(0, (box.top - pad).floor());
    final w = math.min(baked.width - x, (box.width + pad * 2).floor());
    final h = math.min(baked.height - y, (box.height + pad * 2).floor());
    final cropped = img.copyCrop(baked, x: x, y: y, width: w, height: h);

    // ukuran input dibaca dari model [1, H, W, 3]
    final inShape = interpreter.getInputTensor(0).shape;
    final inH = inShape[1];
    final inW = inShape[2];
    final resized = img.copyResize(cropped, width: inW, height: inH);

    final input = Float32List(inH * inW * 3);
    var i = 0;
    for (var py = 0; py < inH; py++) {
      for (var px = 0; px < inW; px++) {
        final p = resized.getPixel(px, py);
        input[i++] = (p.r - 127.5) / 128.0;
        input[i++] = (p.g - 127.5) / 128.0;
        input[i++] = (p.b - 127.5) / 128.0;
      }
    }

    final outLen = interpreter.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(outLen, 0.0)];
    interpreter.run(input.reshape([1, inH, inW, 3]), output);

    return _l2(output[0]);
  }

  List<double> _l2(List<double> v) {
    var sum = 0.0;
    for (final e in v) {
      sum += e * e;
    }
    final n = math.sqrt(sum);
    if (n == 0) return v;
    return v.map((e) => e / n).toList();
  }

  /// cosine similarity (-1..1)
  /// embedding sudah ternormalisasi jadi cukup dot product
  double similarity(List<double> a, List<double> b) {
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }
}