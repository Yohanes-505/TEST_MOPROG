import 'dart:typed_data';

import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

/// Semua akses tabel `profiles` + bucket `avatars`.
class ProfileService {
  const ProfileService();

  static const String _table = 'profiles';
  static const String _bucket = 'avatars';

  String? get currentUserId => supabase.auth.currentUser?.id;

  /// Ambil profil milik user yang sedang login.
  Future<ProfileModel?> getMyProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getProfileById(userId);
  }

  Future<ProfileModel?> getProfileById(String userId) async {
    final data =
        await supabase.from(_table).select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromMap(data);
  }

  /// Simpan data Profile Setup / Edit Profile.
  Future<ProfileModel> saveProfile({
    required String userId,
    String? name,
    int? age,
    String? bio,
    Gender? gender,
    List<String>? interests,
    String? photoUrl,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (age != null) payload['age'] = age;
    if (bio != null) payload['bio'] = bio.trim();
    if (gender != null) payload['gender'] = gender.dbValue;
    if (interests != null) payload['interests'] = interests;
    if (photoUrl != null) payload['photo_url'] = photoUrl;

    // upsert: kalau baris profil belum ada (mis. insert saat signup gagal
    // karena sesi belum aktif), baris dibuat di sini alih-alih error.
    payload['id'] = userId;

    final data = await supabase
        .from(_table)
        .upsert(payload)
        .select()
        .single();

    return ProfileModel.fromMap(data);
  }

  /// Simpan filter preferensi (usia, jarak max, gender).
  Future<ProfileModel> savePreferences({
    required String userId,
    required Gender? prefGender,
    required int minAge,
    required int maxAge,
    required int maxDistanceKm,
  }) async {
    final data = await supabase
        .from(_table)
        .upsert({
          'id': userId,
          'pref_gender': prefGender?.dbValue,
          'pref_min_age': minAge,
          'pref_max_age': maxAge,
          'pref_max_distance_km': maxDistanceKm,
        })
        .select()
        .single();

    return ProfileModel.fromMap(data);
  }

  /// Simpan koordinat GPS ke profil.
  Future<ProfileModel> saveLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final data = await supabase
        .from(_table)
        .upsert({
          'id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'city': city,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    return ProfileModel.fromMap(data);
  }

  /// Upload SATU foto tambahan ke bucket `avatars` dan kembalikan public
  /// URL-nya. Setiap foto dapat nama file unik (timestamp) supaya tidak
  /// saling menimpa — jadi user bisa punya banyak foto sekaligus.
  Future<String> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    String fileExtension = 'jpg',
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final path = '$userId/$fileName';

    await supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false, // nama sudah unik per foto, tidak perlu upsert
            contentType: _contentTypeFor(fileExtension),
          ),
        );

    final publicUrl = supabase.storage.from(_bucket).getPublicUrl(path);

    // Ambil daftar foto yang sudah ada, lalu tambah foto baru ini.
    final current = await getProfileById(userId);
    final updatedUrls = [...(current?.photoUrls ?? const []), publicUrl];

    await supabase.from(_table).upsert({
      'id': userId,
      'photo_urls': updatedUrls,
      'photo_url': updatedUrls.first,
    });

    return publicUrl;
  }

  /// Hapus satu foto dari `photo_urls` (file fisiknya dari storage).
  Future<void> deletePhoto({
    required String userId,
    required String photoUrl,
  }) async {
    final current = await getProfileById(userId);
    if (current == null) return;

    final updatedUrls =
        current.photoUrls.where((u) => u != photoUrl).toList();

    await supabase
        .from(_table)
        .update({
          'photo_urls': updatedUrls,
          'photo_url': updatedUrls.isNotEmpty ? updatedUrls.first : null,
        })
        .eq('id', userId);

    // Hapus file fisiknya dari storage.
    try {
      final uri = Uri.parse(photoUrl);
      final marker = '/$_bucket/';
      final idx = uri.path.indexOf(marker);
      if (idx != -1) {
        final storagePath = uri.path.substring(idx + marker.length);
        await supabase.storage.from(_bucket).remove([storagePath]);
      }
    } catch (_) {
      // Kalau parsing gagal, data di DB sudah konsisten,
    }
  }

  /// Ambil user terdekat sesuai radius + filter preferensi (RPC Haversine).
  Future<List<ProfileModel>> getNearbyProfiles({int limit = 20}) async {
    final result = await supabase.rpc(
      'nearby_profiles',
      params: {'p_limit': limit},
    );
    return (result as List)
        .map((e) => ProfileModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static String _contentTypeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

/// Dipertahankan agar `login_screen.dart` yang sudah ada tidak perlu diubah.
Future<bool> isProfileComplete(String userId) async {
  final profile = await const ProfileService().getProfileById(userId);
  return profile?.isComplete ?? false;
}