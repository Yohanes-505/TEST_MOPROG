import 'package:Meetcha/models/notification_item.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationHistoryService {
  const NotificationHistoryService();

  static const String _table = 'notifications';

  SupabaseClient get _client => Supabase.instance.client;

  String? get _myId => _client.auth.currentUser?.id;

  Future<List<NotificationItem>> getMyNotifications({int limit = 50}) async {
    final userId = _myId;
    if (userId == null) return [];

    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((e) => NotificationItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Gagal ambil daftar notifikasi: $e');
      return [];
    }
  }

  /// jumlah notifikasi yang belum dibaca
  Future<int> getUnreadCount() async {
    final userId = _myId;
    if (userId == null) return 0;

    try {
      final rows = await _client
          .from(_table)
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (rows as List).length;
    } catch (e) {
      debugPrint('Gagal hitung notifikasi belum dibaca: $e');
      return 0;
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _client.from(_table).update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint('Gagal tandai notifikasi dibaca: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _myId;
    if (userId == null) return;

    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Gagal tandai semua notifikasi dibaca: $e');
    }
  }
}