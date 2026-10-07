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

    // landmark dibutuhkan buat meluruskan wajah (mata harus horizontal)
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
      ),
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
    final face = faces.first;

    final aligned = _alignFace(baked, face);

    // ukuran input dibaca dari model [1, H, W, 3]
    final inShape = interpreter.getInputTensor(0).shape;
    final inH = inShape[1];
    final inW = inShape[2];
    final resized = img.copyResize(
      aligned,
      width: inW,
      height: inH,
      interpolation: img.Interpolation.average,
    );

    // rata-rata embedding foto asli + foto di-flip horizontal
    // (trik standar supaya hasil lebih stabil)
    final e1 = _run(interpreter, resized, inH, inW);
    final e2 = _run(interpreter, img.flipHorizontal(resized), inH, inW);
    final sum = List<double>.generate(e1.length, (i) => e1[i] + e2[i]);
    return _l2(sum);
  }

  /// crop persegi di sekitar wajah, lalu putar supaya garis mata horizontal
  img.Image _alignFace(img.Image src, Face face) {
    final box = face.boundingBox;

    // sudut kemiringan dari dua mata (urut berdasarkan x biar nggak ketuker
    // kiri/kanan), fallback ke headEulerAngleZ kalau landmark tidak ada
    double tiltDeg = 0;
    final le = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final re = face.landmarks[FaceLandmarkType.rightEye]?.position;
    if (le != null && re != null) {
      final a = le.x <= re.x ? le : re;
      final b = le.x <= re.x ? re : le;
      tiltDeg = math.atan2((b.y - a.y).toDouble(), (b.x - a.x).toDouble()) *
          180 /
          math.pi;
    } else {
      tiltDeg = -(face.headEulerAngleZ ?? 0);
    }

    // crop persegi lebih besar dulu (margin buat sudut putar),
    // pakai pusat wajah sebagai titik tengah
    final cx = box.center.dx;
    final cy = box.center.dy;
    final side = math.max(box.width, box.height) * 1.6;
    final big = _cropSquare(src, cx, cy, side);

    // copyRotate: sudut positif = searah jarum jam.
    // garis mata miring searah jarum jam (tiltDeg > 0) → putar berlawanan.
    final rotated = tiltDeg.abs() < 1
        ? big
        : img.copyRotate(
            big,
            angle: -tiltDeg,
            interpolation: img.Interpolation.linear,
          );

    // ambil bagian tengah (wajah + sedikit margin), buang sudut hitam hasil rotasi
    final inner = math.max(box.width, box.height) * 1.2;
    return _cropSquare(rotated, rotated.width / 2, rotated.height / 2, inner);
  }

  /// crop persegi berpusat di (cx, cy); kalau keluar batas, geser ke dalam
  /// supaya wajah tidak ikut bergeser/terpotong
  img.Image _cropSquare(img.Image src, double cx, double cy, double side) {
    final s = math.min(side, math.min(src.width, src.height).toDouble());
    final x = (cx - s / 2).clamp(0.0, src.width - s).floor();
    final y = (cy - s / 2).clamp(0.0, src.height - s).floor();
    final size = s.floor();
    return img.copyCrop(src, x: x, y: y, width: size, height: size);
  }

  List<double> _run(Interpreter interpreter, img.Image image, int h, int w) {
    final input = Float32List(h * w * 3);
    var i = 0;
    for (var py = 0; py < h; py++) {
      for (var px = 0; px < w; px++) {
        final p = image.getPixel(px, py);
        input[i++] = (p.r - 127.5) / 128.0;
        input[i++] = (p.g - 127.5) / 128.0;
        input[i++] = (p.b - 127.5) / 128.0;
      }
    }

    final outLen = interpreter.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(outLen, 0.0)];
    interpreter.run(input.reshape([1, h, w, 3]), output);
    return List<double>.from(output[0]);
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