import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bumble/controllers/profile_controller.dart';

import 'face_matcher.dart';

class FaceCheckResult {
  final bool passed;
  final String message;
  final double? smile;
  final double? leftEye;
  final double? rightEye;
  final double? similarity;

  const FaceCheckResult({
    required this.passed,
    required this.message,
    this.smile,
    this.leftEye,
    this.rightEye,
    this.similarity,
  });
}

class FaceVerificationService {
  FaceVerificationService._();
  static final instance = FaceVerificationService._();

  final _supabase = Supabase.instance.client;

  static const _profilesTable = 'profiles';
  static const _profilesIdColumn = 'id';

  static const double _minSmile = 0.7;
  static const double _minEyeOpen = 0.5;
  static const double _maxHeadAngle = 20;

  // Batas kemiripan cosine
  static const double _matchThreshold = 0.5;

  // cek liveness dasar dan badnndingin dengan foto profil
  Future<FaceCheckResult> analyze(File image) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    late final FaceCheckResult live;
    try {
      final faces =
          await detector.processImage(InputImage.fromFilePath(image.path));

      if (faces.isEmpty) {
        return const FaceCheckResult(
            passed: false,
            message:
                'Wajah tidak terdeteksi. Pastikan wajah terlihat jelas & cahaya cukup.');
      }
      if (faces.length > 1) {
        return const FaceCheckResult(
            passed: false,
            message:
                'Terdeteksi lebih dari 1 wajah. Pastikan hanya kamu yang ada di foto.');
      }

      final f = faces.first;
      final smile = f.smilingProbability;
      final left = f.leftEyeOpenProbability;
      final right = f.rightEyeOpenProbability;
      final yaw = f.headEulerAngleY ?? 0;
      final roll = f.headEulerAngleZ ?? 0;

      FaceCheckResult fail(String m) => FaceCheckResult(
          passed: false, message: m, smile: smile, leftEye: left, rightEye: right);

      if (yaw.abs() > _maxHeadAngle || roll.abs() > _maxHeadAngle) {
        return fail('Hadapkan wajah lurus ke kamera.');
      }
      if ((left ?? 0) < _minEyeOpen || (right ?? 0) < _minEyeOpen) {
        return fail('Buka matamu lebar-lebar ya.');
      }
      if ((smile ?? 0) < _minSmile) {
        return fail('Senyum yang lebar dulu ya 😊');
      }

      live = FaceCheckResult(
          passed: true, message: '', smile: smile, leftEye: left, rightEye: right);
    } finally {
      await detector.close();
    }

    // bandingin dengan foto profil
    File? profileFile;
    try {
      profileFile = await _downloadProfilePhoto();
      if (profileFile == null) {
        return FaceCheckResult(
            passed: false,
            message:
                'Kamu belum punya foto profil. Upload foto profil dulu sebelum verifikasi.',
            smile: live.smile, leftEye: live.leftEye, rightEye: live.rightEye);
      }

      final matcher = FaceMatcher.instance;
      final profileEmb = await matcher.embed(profileFile);
      if (profileEmb == null) {
        return FaceCheckResult(
            passed: false,
            message:
                'Wajah tidak terdeteksi di foto profilmu. Ganti foto profil dengan foto wajah yang jelas.',
            smile: live.smile, leftEye: live.leftEye, rightEye: live.rightEye);
      }
      final selfieEmb = await matcher.embed(image);
      if (selfieEmb == null) {
        return FaceCheckResult(
            passed: false,
            message: 'Wajah di selfie tidak terbaca, coba ulangi.',
            smile: live.smile, leftEye: live.leftEye, rightEye: live.rightEye);
      }

      final score = matcher.similarity(profileEmb, selfieEmb);
      debugPrint('[FaceVerif] similarity=$score (threshold=$_matchThreshold)');

      if (score < _matchThreshold) {
        return FaceCheckResult(
            passed: false,
            message: 'Wajahmu tidak cocok dengan foto profil. Coba lagi dengan cahaya lebih baik.',
            smile: live.smile, leftEye: live.leftEye, rightEye: live.rightEye,
            similarity: score);
      }

      return FaceCheckResult(
          passed: true,
          message: 'Wajah cocok dengan foto profil. Verifikasi berhasil!',
          smile: live.smile, leftEye: live.leftEye, rightEye: live.rightEye,
          similarity: score);
    } finally {
      if (profileFile != null && await profileFile.exists()) {
        await profileFile.delete();
      }
    }
  }

  Future<File?> _downloadProfilePhoto() async {
    final url = ProfileController.to.me?.photoUrl;
    if (url == null || !url.startsWith('http')) return null;

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final bytes = await res.fold<List<int>>([], (p, e) => p..addAll(e));
      final f = File(
          '${Directory.systemTemp.path}/profile_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await f.writeAsBytes(bytes);
      return f;
    } finally {
      client.close();
    }
  }

  // upload selfie dan simpan record
  Future<void> submit(File image, FaceCheckResult result) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Sesi login tidak ditemukan');

    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _supabase.storage.from('face-verifications').upload(
          path,
          image,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    await _supabase.from('face_verifications').insert({
      'user_id': user.id,
      'selfie_path': path,
      'status': 'verified',
      'smile_prob': result.smile,
      'left_eye_open_prob': result.leftEye,
      'right_eye_open_prob': result.rightEye,
      'similarity': result.similarity,
    });
  }

  Future<bool> isVerified() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final row = await _supabase
        .from(_profilesTable)
        .select('is_face_verified')
        .eq(_profilesIdColumn, user.id)
        .maybeSingle();
    return (row?['is_face_verified'] as bool?) ?? false;
  }
}