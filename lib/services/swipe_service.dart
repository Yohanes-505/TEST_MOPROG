import 'package:bumble/models/profile_model.dart';
import 'package:bumble/services/block_service.dart';
import 'package:bumble/services/match_chat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SwipeAction {
  like('like'),
  dislike('pass');

  const SwipeAction(this.dbValue);
  final String dbValue;
}

/// Hasil swipe dari server.
class SwipeResult {
  final bool isMatch;

  /// Sisa like hari ini. `null` = tanpa batas (Premium/VIP).
  final int? remainingLikes;

  const SwipeResult({required this.isMatch, this.remainingLikes});
}

/// Dilempar saat user Free sudah menghabiskan jatah like hariannya.
class SwipeLimitReachedException implements Exception {
  final int dailyLimit;
  const SwipeLimitReachedException(this.dailyLimit);

  @override
  String toString() => 'Batas $dailyLimit like per hari sudah tercapai.';
}

/// Hasil rewind: id profil yang swipe-nya dibatalkan.
class RewindResult {
  final String targetId;
  final String action;
  const RewindResult({required this.targetId, required this.action});
}

class RewindException implements Exception {
  /// 'upgrade_required' | 'nothing_to_rewind' | 'already_matched' | lainnya
  final String code;
  const RewindException(this.code);

  String get message {
    switch (code) {
      case 'upgrade_required':
        return 'Rewind hanya tersedia untuk Premium dan VIP.';
      case 'nothing_to_rewind':
        return 'Belum ada swipe yang bisa dibatalkan.';
      case 'already_matched':
        return 'Swipe ini sudah jadi match, tidak bisa dibatalkan.';
      default:
        return 'Rewind gagal. Coba lagi.';
    }
  }

  @override
  String toString() => message;
}

class SwipeService {
  const SwipeService();

  SupabaseClient get _client => Supabase.instance.client;

  /// Versi lama (dipakai LikesScreen): mengembalikan `true` kalau MATCH.
  Future<bool> submit({
    required String targetId,
    required SwipeAction action,
  }) async {
    final result = await submitDetailed(targetId: targetId, action: action);
    return result.isMatch;
  }

  /// Simpan pilihan lewat RPC `submit_swipe`. Kuota like harian dicek di
  /// server, jadi tidak bisa dilewati dengan memodifikasi app.
  Future<SwipeResult> submitDetailed({
    required String targetId,
    required SwipeAction action,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      throw StateError('Sesi berakhir. Silakan login ulang.');
    }

    final dynamic raw;
    try {
      raw = await _client.rpc('submit_swipe', params: {
        'p_target': targetId,
        'p_action': action.dbValue,
      });
    } on PostgrestException catch (e) {
      debugPrint(
        'Gagal menyimpan swipe: [${e.code}] ${e.message} | ${e.details}',
      );
      rethrow;
    }

    final map = Map<String, dynamic>.from(raw as Map);

    if (map['ok'] != true) {
      switch (map['error']) {
        case 'limit_reached':
          throw SwipeLimitReachedException(
            (map['daily_limit'] as num?)?.toInt() ?? 20,
          );
        case 'blocked':
          throw StateError('Pengguna ini tidak tersedia.');
        default:
          throw StateError('Swipe gagal (${map['error']}).');
      }
    }

    final isMatch = map['is_match'] == true;
    if (isMatch) MatchChatService.notifyMatchesChanged();

    return SwipeResult(
      isMatch: isMatch,
      remainingLikes: (map['remaining_likes'] as num?)?.toInt(),
    );
  }

  /// Batalkan swipe terakhir (Premium/VIP).
  Future<RewindResult> rewind() async {
    final raw = await _client.rpc('rewind_last_swipe');
    final map = Map<String, dynamic>.from(raw as Map);

    if (map['ok'] != true) {
      throw RewindException(map['error']?.toString() ?? 'unknown');
    }
    return RewindResult(
      targetId: map['target_id'].toString(),
      action: map['action']?.toString() ?? '',
    );
  }

  Future<List<ProfileModel>> getPendingLikerProfiles(
    List<String> likerIds,
  ) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null || likerIds.isEmpty) return [];

    final mySwipes = await _client
        .from('swipes')
        .select('swiped_id')
        .eq('swiper_id', myId);
    final respondedIds = mySwipes.map((e) => e['swiped_id'].toString()).toSet();

    // user yg sudah saling block gak boleh nongol di daftar menyukaimu
    final hiddenIds = await BlockService.getHiddenUserIds(myId);

    final pendingIds = likerIds
        .where((id) => !respondedIds.contains(id) && !hiddenIds.contains(id))
        .toList();
    if (pendingIds.isEmpty) return [];

    final rows =
        await _client.from('profiles').select().inFilter('id', pendingIds);
    return rows.map(ProfileModel.fromMap).toList();
  }
}