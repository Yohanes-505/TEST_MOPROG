import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

/// Hasil pengambilan lokasi: selalu mengembalikan objek, tidak melempar
/// exception, supaya UI gampang menampilkan pesan yang tepat.
class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? errorMessage;
  final LocationFailure? failure;

  const LocationResult._({
    this.latitude,
    this.longitude,
    this.city,
    this.errorMessage,
    this.failure,
  });

  const LocationResult.success({
    required double lat,
    required double lng,
    String? city,
  }) : this._(latitude: lat, longitude: lng, city: city);

  const LocationResult.failure(
    String message, {
    LocationFailure type = LocationFailure.unknown,
  }) : this._(errorMessage: message, failure: type);

  bool get isSuccess => errorMessage == null;
}

/// Semua urusan GPS ada di sini (node "Lokasi GPS" & "radius GPS").
class LocationService {
  const LocationService();

  static const Duration _fixTimeout = Duration(seconds: 60);

  static const Duration _geocodeTimeout = Duration(seconds: 8);

  static const Duration _lastKnownMaxAge = Duration(minutes: 30);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<LocationResult> getCurrentLocation({
    bool resolveCity = true,
    bool requestPermission = true,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult.failure(
          'Layanan lokasi mati. Nyalakan GPS di pengaturan perangkat.',
          type: LocationFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const LocationResult.failure(
            'Izin lokasi ditolak. Kami butuh lokasi untuk mencari orang di sekitarmu.',
            type: LocationFailure.permissionDenied,
          );
        case LocationPermission.deniedForever:
          return const LocationResult.failure(
            'Izin lokasi diblokir permanen. Buka pengaturan aplikasi untuk mengizinkannya.',
            type: LocationFailure.permissionDeniedForever,
          );
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }

      final position = await _fetchPosition();
      if (position == null || !_isValid(position)) {
        return const LocationResult.failure(
          'Belum bisa menemukan lokasimu. Pastikan GPS aktif, lalu coba lagi.',
          type: LocationFailure.timeout,
        );
      }

      String? city;
      if (resolveCity) {
        city = await _resolveCity(position.latitude, position.longitude);
      }

      return LocationResult.success(
        lat: position.latitude,
        lng: position.longitude,
        city: city,
      );
    } on LocationServiceDisabledException {
      return const LocationResult.failure(
        'Layanan lokasi mati. Nyalakan GPS di pengaturan perangkat.',
        type: LocationFailure.serviceDisabled,
      );
    } on PermissionDeniedException {
      return const LocationResult.failure(
        'Izin lokasi ditolak. Kami butuh lokasi untuk mencari orang di sekitarmu.',
        type: LocationFailure.permissionDenied,
      );
    } catch (e, st) {
      debugPrint('LocationService error: $e\n$st');
      return const LocationResult.failure(
        'Gagal mengambil lokasi. Coba lagi beberapa saat.',
      );
    }
  }

  /// Buka halaman pengaturan aplikasi (untuk kasus deniedForever).
  Future<void> openSettings() => Geolocator.openAppSettings();

  /// Buka pengaturan layanan lokasi/GPS perangkat (untuk kasus GPS mati).
  Future<void> openLocationServiceSettings() => Geolocator.openLocationSettings();

  /// Jarak dua titik dalam kilometer. Dipakai kalau mau hitung di sisi client.
  double distanceInKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    return meters / 1000;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  LocationSettings _settings({required bool forceLocationManager}) {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _fixTimeout,
        forceLocationManager: forceLocationManager,
      );
    }
    if (_isApple) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: _fixTimeout,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: _fixTimeout,
    );
  }

  Future<Position?> _fetchPosition() async {
    var retryWithLocationManager = false;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _settings(forceLocationManager: false),
      );
    } on TimeoutException {
      debugPrint('Fix GPS timeout, coba lokasi terakhir.');
    } on LocationServiceDisabledException {
      rethrow;
    } on PermissionDeniedException {
      rethrow;
    } catch (e) {
      debugPrint('getCurrentPosition gagal: $e');
      retryWithLocationManager = _isAndroid;
    }

    if (retryWithLocationManager) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: _settings(forceLocationManager: true),
        );
      } on TimeoutException {
        debugPrint('Fix GPS (LocationManager) timeout.');
      } on LocationServiceDisabledException {
        rethrow;
      } on PermissionDeniedException {
        rethrow;
      } catch (e) {
        debugPrint('getCurrentPosition (LocationManager) gagal: $e');
      }
    }

    if (!kIsWeb) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp).abs() <=
                _lastKnownMaxAge) {
          return last;
        }
      } catch (e) {
        debugPrint('getLastKnownPosition gagal: $e');
      }
    }

    return null;
  }

  bool _isValid(Position p) {
    final lat = p.latitude;
    final lng = p.longitude;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  Future<String?> _resolveCity(double lat, double lng) async {
    if (kIsWeb) return null;
    try {
      final placemarks =
          await placemarkFromCoordinates(lat, lng).timeout(_geocodeTimeout);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final candidates = [
        p.subAdministrativeArea,
        p.locality,
        p.administrativeArea,
      ];
      for (final c in candidates) {
        if (c != null && c.trim().isNotEmpty) return c.trim();
      }
      return null;
    } catch (e) {
      debugPrint('Reverse geocode gagal: $e');
      return null;
    }
  }
}