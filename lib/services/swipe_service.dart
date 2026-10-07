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

class SwipeService {
  const SwipeService();

  SupabaseClient get _client => Supabase.instance.client;

  /// Simpan pilihan user. Mengembalikan `true` kalau hasilnya MATCH
  Future<bool> submit({
    required String targetId,
    required SwipeAction action,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      throw StateError('Sesi berakhir. Silakan login ulang.');
    }

    try {
      await _client.from('swipes').upsert(
        {
          'swiper_id': myId,
          'swiped_id': targetId,
          'action': action.dbValue,
        },
        onConflict: 'swiper_id,swiped_id',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        'Gagal menyimpan swipe: [${e.code}] ${e.message} | ${e.details}',
      );
      rethrow;
    }

    if (action != SwipeAction.like) return false;

    final isMatch = await _matchExists(myId, targetId);
    if (isMatch) MatchChatService.notifyMatchesChanged();
    return isMatch;
  }

  Future<bool> _matchExists(String myId, String otherId) async {
    try {
      final rows = await _client
          .from('matches')
          .select('id')
          .or(
            'and(user1_id.eq.$myId,user2_id.eq.$otherId),'
            'and(user1_id.eq.$otherId,user2_id.eq.$myId)',
          )
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('Gagal memeriksa match: $e');
      return false;
    }
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