import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bumble/models/profile_model.dart';

class TierStatus {
  final String tier;
  final int? dailyLimit;
  final int usedLikes;
  final int? remainingLikes;
  final DateTime? boostEndsAt;
  final int boostsLeftToday;
  final bool canRewind;

  TierStatus({
    required this.tier,
    this.dailyLimit,
    required this.usedLikes,
    this.remainingLikes,
    this.boostEndsAt,
    required this.boostsLeftToday,
    required this.canRewind,
  });

  factory TierStatus.fromMap(Map<String, dynamic> map) {
    return TierStatus(
      tier: map['tier'] as String? ?? 'free',
      dailyLimit: map['daily_limit'] as int?,
      usedLikes: map['used_likes'] as int? ?? 0,
      remainingLikes: map['remaining_likes'] as int?,
      boostEndsAt: map['boost_ends_at'] != null 
          ? DateTime.parse(map['boost_ends_at']).toLocal() 
          : null,
      boostsLeftToday: map['boosts_left_today'] as int? ?? 0,
      canRewind: map['can_rewind'] as bool? ?? false,
    );
  }
}

class TierService {
  static final _client = Supabase.instance.client;

  /// Mengambil status tier saat ini beserta limit harian
  static Future<TierStatus> getStatus() async {
    final res = await _client.rpc('get_tier_status');
    return TierStatus.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Mengaktifkan boost profile (Premium/VIP)
  static Future<Map<String, dynamic>> activateBoost() async {
    final res = await _client.rpc('activate_boost');
    return Map<String, dynamic>.from(res as Map);
  }

  /// Mengambil daftar pengguna yang melihat profil kita (Hanya VIP)
  static Future<Map<String, dynamic>> getMyProfileViewers() async {
    final res = await _client.rpc('get_my_profile_viewers');
    final map = Map<String, dynamic>.from(res as Map);
    
    // Parsing list profiles jika eligible
    if (map['eligible'] == true && map['viewers'] != null) {
      final List viewersList = map['viewers'] as List;
      map['parsed_viewers'] = viewersList.map((v) => ProfileModel.fromMap(v)).toList();
    } else {
      map['parsed_viewers'] = <ProfileModel>[];
    }
    
    return map;
  }
}