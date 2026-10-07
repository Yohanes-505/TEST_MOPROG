import 'package:bumble/models/profile_model.dart';
import 'package:flutter/foundation.dart';
import 'package:bumble/services/location_service.dart';
import 'package:bumble/services/profile_service.dart';
import 'package:get/get.dart';

/// State profil user yang sedang login.
/// Dipakai bersama oleh Profile Setup, Tab Profile, Edit Profile,
/// dan Filter Preferensi.
///
/// Daftarkan sekali saja, misalnya lewat `Get.put(ProfileController())`
/// di `main.dart`, atau `Get.lazyPut` sebelum masuk Home.
class ProfileController extends GetxController {
  final ProfileService _profileService = const ProfileService();
  final LocationService _locationService = const LocationService();

  /// Satu-satunya cara mengambil controller ini dari layar mana pun.
  ///
  /// Kalau belum terdaftar (misalnya setelah logout menghapusnya),
  /// dibuat ulang dengan `permanent: true` supaya tidak ikut dibuang
  /// GetX saat layar yang membuatnya ditutup.
  static ProfileController get to => Get.isRegistered<ProfileController>()
      ? Get.find<ProfileController>()
      : Get.put(ProfileController(), permanent: true);

  final Rxn<ProfileModel> profile = Rxn<ProfileModel>();
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isLocating = false.obs;

  ProfileModel? get me => profile.value;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    try {
      profile.value = await _profileService.getMyProfile();
    } catch (e) {
      debugPrint('LOAD PROFILE ERROR: $e');
      _error('Gagal memuat profil.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Simpan data profil. Mengembalikan true kalau berhasil.
  Future<bool> saveProfile({
    String? name,
    int? age,
    String? bio,
    Gender? gender,
    List<String>? interests,
  }) async {
    final userId = _profileService.currentUserId;
    if (userId == null) {
      _error('Sesi berakhir. Silakan login ulang.');
      return false;
    }

    isSaving.value = true;
    try {
      profile.value = await _profileService.saveProfile(
        userId: userId,
        name: name,
        age: age,
        bio: bio,
        gender: gender,
        interests: interests,
      );
      return true;
    } catch (e) {
      _error('Gagal menyimpan profil. Coba lagi.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

/// Upload satu foto tambahan. Bisa dipanggil berkali-kali (mis. dari
  /// tombol "+ Tambah foto") — setiap panggilan menambah satu foto baru
  /// ke `profile.photoUrls`, tidak menimpa yang sudah ada.
  Future<bool> uploadPhoto(Uint8List bytes, {String extension = 'jpg'}) async {
    final userId = _profileService.currentUserId;
    if (userId == null) return false;
 
    isSaving.value = true;
    try {
      final url = await _profileService.uploadPhoto(
        userId: userId,
        bytes: bytes,
        fileExtension: extension,
      );
      // Tambahkan foto baru ke daftar yang sudah ada, alih-alih menimpa.
      final updatedUrls = <String>[...(profile.value?.photoUrls ?? const []), url];
      profile.value = profile.value?.copyWith(photoUrls: updatedUrls);
      return true;
    } catch (e) {
      _error('Gagal mengunggah foto. Pastikan ukuran file wajar.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }
 
  /// Hapus satu foto dari profil (dan dari storage).
  Future<bool> deletePhoto(String photoUrl) async {
    final userId = _profileService.currentUserId;
    if (userId == null) return false;
 
    isSaving.value = true;
    try {
      await _profileService.deletePhoto(userId: userId, photoUrl: photoUrl);
      final updatedUrls =
          (profile.value?.photoUrls ?? const [])
              .where((u) => u != photoUrl)
              .toList();
      profile.value = profile.value?.copyWith(photoUrls: updatedUrls);
      return true;
    } catch (e) {
      _error('Gagal menghapus foto.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Ambil lokasi GPS lalu simpan ke profil.
  Future<bool> refreshLocation({bool silent = false}) async {
    final userId = _profileService.currentUserId;
    if (userId == null) return false;

    isLocating.value = true;
    try {
      final result = await _locationService.getCurrentLocation();

      if (!result.isSuccess) {
        if (!silent) _error(result.errorMessage!);
        return false;
      }

      profile.value = await _profileService.saveLocation(
        userId: userId,
        latitude: result.latitude!,
        longitude: result.longitude!,
        city: result.city,
      );

      if (!silent) {
        Get.snackbar(
          'Lokasi diperbarui',
          result.city == null
              ? 'Lokasi kamu berhasil disimpan.'
              : 'Lokasi kamu: ${result.city}',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return true;
      } catch (e) {
      debugPrint('LOCATION SAVE ERROR: $e');
      if (!silent) _error('Gagal menyimpan lokasi.');
      return false;
    } finally {
      isLocating.value = false;
    }
  }

  Future<bool> savePreferences({
    required Gender? prefGender,
    required int minAge,
    required int maxAge,
    required int maxDistanceKm,
  }) async {
    final userId = _profileService.currentUserId;
    if (userId == null) return false;

    isSaving.value = true;
    try {
      profile.value = await _profileService.savePreferences(
        userId: userId,
        prefGender: prefGender,
        minAge: minAge,
        maxAge: maxAge,
        maxDistanceKm: maxDistanceKm,
      );
      return true;
    } catch (e) {
      _error('Gagal menyimpan filter preferensi.');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openLocationSettings() => _locationService.openSettings();

  void _error(String message) {
    Get.snackbar('Error', message, snackPosition: SnackPosition.BOTTOM);
  }
}