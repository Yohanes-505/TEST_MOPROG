/// Gender user.

enum Gender {
  male,
  female,
  // nonBinary,
}

extension GenderX on Gender {
  /// Nilai yang disimpan di kolom `profiles.gender`.
  String get dbValue {
    switch (this) {
      case Gender.male:
        return 'male';
      case Gender.female:
        return 'female';
      // case Gender.nonBinary:
      //   return 'non_binary';
    }
  }

  String get label {
    switch (this) {
      case Gender.male:
        return 'Laki-laki';
      case Gender.female:
        return 'Perempuan';
      // case Gender.nonBinary:
      //   return 'Non-binary';
    }
  }

  static Gender? fromDb(String? value) {
    if (value == null) return null;
    for (final g in Gender.values) {
      if (g.dbValue == value) return g;
    }
    return null;
  }
}

class ProfileModel {
  final String id;
  final String name;
  final int? age;
  final String? bio;
  final Gender? gender;
  final String? photoUrl;
  final List<String>photoUrls;
  final List<String> interests;

  // Lokasi (GPS)
  final double? latitude;
  final double? longitude;
  final String? city;
  final DateTime? locationUpdatedAt;

  // Filter preferensi
  final Gender? prefGender; // null = semua gender
  final int prefMinAge;
  final int prefMaxAge;
  final int prefMaxDistanceKm;

  final DateTime? createdAt;

  /// Hanya terisi kalau row berasal dari RPC `nearby_profiles`.
  final double? distanceKm;

  const ProfileModel({
    required this.id,
    required this.name,
    this.age,
    this.bio,
    this.gender,
    this.photoUrl,
    this.photoUrls = const [],
    this.interests = const [],
    this.latitude,
    this.longitude,
    this.city,
    this.locationUpdatedAt,
    this.prefGender,
    this.prefMinAge = 18,
    this.prefMaxAge = 40,
    this.prefMaxDistanceKm = 50,
    this.createdAt,
    this.distanceKm,
  });

  bool get hasLocation => latitude != null && longitude != null;

  /// Dipakai untuk menentukan apakah user boleh masuk ke Home.
  bool get isComplete =>
      age != null && gender != null && interests.isNotEmpty && hasLocation;

  /// Persentase kelengkapan profil, untuk progress bar di Tab Profile.
  double get completeness {
    final checks = <bool>[
      name.trim().isNotEmpty,
      age != null,
      gender != null,
      (bio ?? '').trim().isNotEmpty,
      (photoUrl ?? '').isNotEmpty,
      interests.isNotEmpty,
      hasLocation,
    ];
    final done = checks.where((c) => c).length;
    return done / checks.length;
  }

  String get distanceLabel {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return 'Kurang dari 1 km';
    return '${distanceKm!.round()} km dari kamu';
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      age: (map['age'] as num?)?.toInt(),
      bio: map['bio'] as String?,
      gender: GenderX.fromDb(map['gender'] as String?),
      photoUrl: map['photo_url'] as String?,
      photoUrls: _photoUrlsFrom(map),
      interests: (map['interests'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      city: map['city'] as String?,
      locationUpdatedAt: _parseDate(map['location_updated_at']),
      prefGender: GenderX.fromDb(map['pref_gender'] as String?),
      prefMinAge: (map['pref_min_age'] as num?)?.toInt() ?? 18,
      prefMaxAge: (map['pref_max_age'] as num?)?.toInt() ?? 40,
      prefMaxDistanceKm: (map['pref_max_distance_km'] as num?)?.toInt() ?? 50,
      createdAt: _parseDate(map['created_at']),
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
    );
  }

  /// Field profil yang boleh diedit user (dipakai untuk update ke Supabase).
  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'age': age,
      'bio': bio,
      'gender': gender?.dbValue,
      'photo_url': photoUrl,
      'photo_urls': photoUrls,
      'interests': interests,
    };
  }

  Map<String, dynamic> toPreferenceMap() {
    return {
      'pref_gender': prefGender?.dbValue,
      'pref_min_age': prefMinAge,
      'pref_max_age': prefMaxAge,
      'pref_max_distance_km': prefMaxDistanceKm,
    };
  }

  ProfileModel copyWith({
    String? name,
    int? age,
    String? bio,
    Gender? gender,
    String? photoUrl,
    List<String>? photoUrls,
    List<String>? interests,
    double? latitude,
    double? longitude,
    String? city,
    DateTime? locationUpdatedAt,
    Gender? prefGender,
    bool clearPrefGender = false,
    int? prefMinAge,
    int? prefMaxAge,
    int? prefMaxDistanceKm,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      interests: interests ?? this.interests,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      prefGender: clearPrefGender ? null : (prefGender ?? this.prefGender),
      prefMinAge: prefMinAge ?? this.prefMinAge,
      prefMaxAge: prefMaxAge ?? this.prefMaxAge,
      prefMaxDistanceKm: prefMaxDistanceKm ?? this.prefMaxDistanceKm,
      createdAt: createdAt,
      distanceKm: distanceKm,
    );
  }

  static List<String> _photoUrlsFrom(Map<String, dynamic> map) {
    final urls = (map['photo_urls'] as List?)
            ?.map((e) => e.toString())
            .where((u) => u.isNotEmpty)
            .toList() ??
        <String>[];
    if (urls.isNotEmpty) return urls;

    final single = map['photo_url'] as String?;
    return (single != null && single.isNotEmpty) ? [single] : <String>[];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}