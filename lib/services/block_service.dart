import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/block_model.dart';

class BlockService {
  static final _supabase = Supabase.instance.client;

  /// Block
  static Future<bool> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      final block = BlockModel(blockerId: blockerId, blockedId: blockedId);
      await _supabase.from('blocks').insert(block.toMap());
      return true;
    } catch (e) {
      debugPrint('Gagal block user: $e');
      return false;
    }
  }

  /// Unblock
  static Future<bool> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _supabase
          .from('blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);
      return true;
    } catch (e) {
      debugPrint('Gagal unblock user: $e');
      return false;
    }
  }

  /// Ngecek blockerId sudah ngeblock blockedId
  static Future<bool> isBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      final result = await _supabase
          .from('blocks')
          .select('id')
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('Gagal cek status block: $e');
      return false;
    }
  }

  /// Ngmbil daftar id user yang diblock oleh currentUserId
  static Future<List<String>> getBlockedUserIds(String currentUserId) async {
    try {
      final result = await _supabase
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);

      return (result as List)
          .map((row) => row['blocked_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('Gagal ambil daftar blocked users: $e');
      return [];
    }
  }
}