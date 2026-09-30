import 'package:bumble/models/chat_message.dart';
import 'package:bumble/models/match_preview.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class MatchChatService {
  const MatchChatService();

  /// (tab Match dibuka, atau ada match baru dari Home/Likes).
  /// Layar Match mendengarkan ini lalu memuat ulang datanya.
  static final ValueNotifier<int> matchesChanged = ValueNotifier<int>(0);
  static void notifyMatchesChanged() => matchesChanged.value++;

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<ProfileModel>> getMyMatches() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final counterparts = _counterparts(await _fetchMatchRows(myId), myId);
    final profiles = await _fetchProfiles(counterparts.keys);
    return profiles.values.toList();
  }

  Future<List<MatchPreview>> getMatchPreviews() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final counterparts = _counterparts(await _fetchMatchRows(myId), myId);
    if (counterparts.isEmpty) return [];

    final profiles = await _fetchProfiles(counterparts.keys);

    final previews = await Future.wait(
      counterparts.entries
          .where((e) => profiles.containsKey(e.key))
          .map((e) async {
        final last = await _getLastMessage(myId, e.key);
        return MatchPreview(
          profile: profiles[e.key]!,
          matchedAt: e.value,
          lastMessage: last?.text,
          lastMessageAt: last?.createdAt,
          lastMessageIsMine: last?.senderId == myId,
        );
      }),
    );

    final list = previews.toList();
    list.sort((a, b) {
      final ta = a.lastMessageAt ?? a.matchedAt;
      final tb = b.lastMessageAt ?? b.matchedAt;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return list;
  }

  Future<List<Map<String, dynamic>>> _fetchMatchRows(String myId) async {
    final rows = await _client
        .from('matches')
        .select()
        .or('user1_id.eq.$myId,user2_id.eq.$myId');
    return List<Map<String, dynamic>>.from(rows);
  }

  Map<String, DateTime?> _counterparts(
    List<Map<String, dynamic>> rows,
    String myId,
  ) {
    final result = <String, DateTime?>{};
    for (final row in rows) {
      final a = row['user1_id'].toString();
      final b = row['user2_id'].toString();
      final other = a == myId ? b : a;
      final at = DateTime.tryParse('${row['created_at']}')?.toLocal();

      final existing = result[other];
      if (!result.containsKey(other) ||
          (at != null && (existing == null || at.isAfter(existing)))) {
        result[other] = at;
      }
    }
    return result;
  }

  Future<Map<String, ProfileModel>> _fetchProfiles(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return {};

    final rows = await _client.from('profiles').select().inFilter('id', list);
    return {
      for (final row in rows) row['id'].toString(): ProfileModel.fromMap(row),
    };
  }

  static String _conversationFilter(String myId, String otherId) =>
      'and(sender_id.eq.$myId,receiver_id.eq.$otherId),'
      'and(sender_id.eq.$otherId,receiver_id.eq.$myId)';

  Future<ChatMessage?> _getLastMessage(String myId, String otherId) async {
    final row = await _client
        .from('messages')
        .select()
        .or(_conversationFilter(myId, otherId))
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : ChatMessage.fromMap(row);
  }

  Future<List<ChatMessage>> getMessages(String otherId, {int limit = 200}) async {
    final myId = currentUserId;
    if (myId == null) return [];

    final rows = await _client
        .from('messages')
        .select()
        .or(_conversationFilter(myId, otherId))
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<ChatMessage> sendMessage({
    required String receiverId,
    required String text,
  }) async {
    final myId = currentUserId;
    if (myId == null) {
      throw StateError('Sesi berakhir. Silakan login ulang.');
    }

    final row = await _client
        .from('messages')
        .insert({
          'sender_id': myId,
          'receiver_id': receiverId,
          'message': text,
        })
        .select()
        .single();
    return ChatMessage.fromMap(row);
  }

  RealtimeChannel subscribeToIncomingMessages({
    required String fromUserId,
    required void Function(ChatMessage message) onMessage,
  }) {
    final myId = currentUserId ?? '';
    return _client
        .channel('chat-$myId-$fromUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) {
            final message = ChatMessage.fromMap(payload.newRecord);
            if (message.senderId == fromUserId) onMessage(message);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToAnyIncomingMessage(VoidCallback onChange) {
    final myId = currentUserId ?? '';
    return _client
        .channel('inbox-$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
