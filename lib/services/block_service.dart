import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/block_model.dart';
import '../models/profile_model.dart';

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
          .select('blocker_id')
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

  /// ngambil daftar profil lengkap dari user yang diblock 
  static Future<List<ProfileModel>> getBlockedProfiles(
    String currentUserId,
  ) async {
    try {
      final blockedIds = await getBlockedUserIds(currentUserId);
      if (blockedIds.isEmpty) return [];

      final rows = await _supabase
          .from('profiles')
          .select()
          .inFilter('id', blockedIds);

      return (rows as List)
          .map((e) => ProfileModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Gagal ambil daftar profil yang diblokir: $e');
      return [];
    }
  }

  /// ngambil semua id user yang harus disembunyikan dari swipe stack
  static Future<Set<String>> getHiddenUserIds(String currentUserId) async {
    try {
      final blockedByMe = await _supabase
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);

      final blockedMe = await _supabase
          .from('blocks')
          .select('blocker_id')
          .eq('blocked_id', currentUserId);

      final ids = <String>{};
      for (final row in (blockedByMe as List)) {
        ids.add(row['blocked_id'] as String);
      }
      for (final row in (blockedMe as List)) {
        ids.add(row['blocker_id'] as String);
      }
      return ids;
    } catch (e) {
      debugPrint('Gagal ambil daftar hidden users: $e');
      return {};
    }
  }
}