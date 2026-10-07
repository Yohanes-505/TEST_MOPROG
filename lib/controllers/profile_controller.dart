import 'package:bumble/models/profile_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bumble/services/location_service.dart';
import 'package:bumble/services/profile_service.dart';
import 'package:get/get.dart';

/// State profil user yang sedang login.
/// Dipakai bersama oleh Profile Setup, Tab Profile, Edit Profile,
/// dan Filter Preferensi.
///
/// Daftarkan sekali saja, misalnya lewat `Get.put(ProfileController())`
/// di `main.dart`, atau `Get.lazyPut` sebelum masuk Home.
class ProfileController extends GetxController
    with WidgetsBindingObserver {
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

  /// Lokasi yang lebih tua dari ini dianggap basi dan diperbarui otomatis
  /// saat aplikasi dibuka kembali.
  static const Duration _locationMaxAge = Duration(minutes: 5);

  /// Jeda minimal antar refresh otomatis (supaya tidak spam GPS).
  static const Duration _autoRetryGap = Duration(seconds: 30);
  DateTime? _lastAutoRefresh;

  ProfileModel? get me => profile.value;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    loadProfile();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Saat user kembali ke aplikasi (mis. setelah menyalakan GPS di
  /// pengaturan atau berpindah tempat), segarkan lokasi kalau sudah basi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshLocationIfNeeded();
    }
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

  // Ini buat perbaruin lokasi setiap beberapa saat (kalau keluar dari aplikasi sekitar 30 menitan maksimal).
  Future<void> refreshLocationIfNeeded({bool force = false}) async {
    if (isClosed || isLocating.value) return;
    if (_profileService.currentUserId == null) return;

    if (profile.value == null) {
      await loadProfile();
    }
    final p = profile.value;
    if (isClosed || p == null) return;

    final updatedAt = p.locationUpdatedAt;
    final isStale = !p.hasLocation ||
        updatedAt == null ||
        DateTime.now().difference(updatedAt) > _locationMaxAge;
    if (!force && !isStale) return;

    final last = _lastAutoRefresh;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _autoRetryGap) {
      return;
    }
    _lastAutoRefresh = DateTime.now();

    await refreshLocation(silent: true);
  }

  /// Ambil lokasi GPS lalu simpan ke profil.
  Future<bool> refreshLocation({bool silent = false}) async {
    if (isClosed) return false;
    final userId = _profileService.currentUserId;
    if (userId == null) return false;
    if (isLocating.value) return false;
    isLocating.value = true;

    try {
      final result = await _locationService.getCurrentLocation(
        requestPermission: !silent,
      );

      if (isClosed) return false;

      if (!result.isSuccess) {
        if (!silent) _locationError(result);
        return false;
      }

      final saved = await _profileService.saveLocation(
        userId: userId,
        latitude: result.latitude!,
        longitude: result.longitude!,
        city: result.city,
      );

      if (isClosed) return false;
      profile.value = saved;

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
    } catch (e, st) {
      debugPrint('LOCATION SAVE ERROR: $e\n$st');
      if (!silent && !isClosed) _error('Gagal menyimpan lokasi.');
      return false;
    } finally {
      if (!isClosed) isLocating.value = false;
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

  // Jika error atau belum menyalakan pengaturan maka bakal muncul buka pengaturan.
  void _locationError(LocationResult result) {
    final VoidCallback? openAction;
    switch (result.failure) {
      case LocationFailure.permissionDeniedForever:
        openAction = () => _locationService.openSettings();
        break;
      case LocationFailure.serviceDisabled:
        openAction = () => _locationService.openLocationServiceSettings();
        break;
      default:
        openAction = null;
    }

    Get.snackbar(
      'Error',
      result.errorMessage ?? 'Gagal mengambil lokasi.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
      mainButton: openAction == null
          ? null
          : TextButton(
              onPressed: openAction,
              child: const Text('Buka Pengaturan'),
            ),
    );
  }

  void _error(String message) {
    Get.snackbar('Error', message, snackPosition: SnackPosition.BOTTOM);
  }
}