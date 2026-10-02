import 'package:bumble/models/chat_message.dart';
import 'package:bumble/models/match_preview.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/utils/network_error.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

///
/// Tabel `messages` hanya punya `match_id` (tidak ada receiver_id), jadi
/// sebelum membaca/mengirim pesan kita perlu tahu id baris `matches`-nya.
class ChatRoom {
  final String primaryMatchId;
  final List<String> matchIds;

  const ChatRoom({required this.primaryMatchId, required this.matchIds});
}

class _MatchRef {
  final List<String> ids = [];
  DateTime? matchedAt;
}

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

    final refs = _groupByCounterpart(await _fetchMatchRows(myId), myId);
    final profiles = await _fetchProfiles(refs.keys);
    return profiles.values.toList();
  }

  Future<List<MatchPreview>> getMatchPreviews() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final refs = _groupByCounterpart(await _fetchMatchRows(myId), myId);
    if (refs.isEmpty) return [];

    final profiles = await _fetchProfiles(refs.keys);

    final previews = await Future.wait(
      refs.entries.where((e) => profiles.containsKey(e.key)).map((e) async {
        final last = await _getLastMessage(e.value.ids);
        return MatchPreview(
          profile: profiles[e.key]!,
          matchedAt: e.value.matchedAt,
          matchIds: List<String>.unmodifiable(e.value.ids),
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
    final rows = await withRetry(
      () async => await _client
          .from('matches')
          .select()
          .or('user1_id.eq.$myId,user2_id.eq.$myId')
          .order('created_at', ascending: true)
          .order('id', ascending: true),
    );
    return List<Map<String, dynamic>>.from(rows);
  }

  Map<String, _MatchRef> _groupByCounterpart(
    List<Map<String, dynamic>> rows,
    String myId,
  ) {
    final result = <String, _MatchRef>{};
    for (final row in rows) {
      final a = row['user1_id'].toString();
      final b = row['user2_id'].toString();
      final other = a == myId ? b : a;
      if (other == myId) continue;
      final ref = result.putIfAbsent(other, () => _MatchRef());
      ref.ids.add(row['id'].toString());

      final at = DateTime.tryParse('${row['created_at']}')?.toLocal();
      if (at != null && (ref.matchedAt == null || at.isAfter(ref.matchedAt!))) {
        ref.matchedAt = at;
      }
    }
    return result;
  }

  Future<Map<String, ProfileModel>> _fetchProfiles(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return {};

    final rows = await withRetry(
      () async => await _client.from('profiles').select().inFilter('id', list),
    );
    return {
      for (final row in rows) row['id'].toString(): ProfileModel.fromMap(row),
    };
  }

  Future<ChatMessage?> _getLastMessage(List<String> matchIds) async {
    if (matchIds.isEmpty) return null;
    try {
      final row = await withRetry(
        () async => await _client
            .from('messages')
            .select()
            .inFilter('match_id', matchIds)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
        attempts: 2,
      );
      return row == null ? null : ChatMessage.fromMap(row);
    } catch (e) {
      debugPrint('Gagal memuat pesan terakhir: $e');
      return null;
    }
  }

  Future<ChatRoom> openRoom(String otherId) async {
    final myId = currentUserId;
    if (myId == null) {
      throw StateError('Sesi berakhir. Silakan login ulang.');
    }

    final rows = await withRetry(
      () async => await _client
          .from('matches')
          .select('id')
          .or(
            'and(user1_id.eq.$myId,user2_id.eq.$otherId),'
            'and(user1_id.eq.$otherId,user2_id.eq.$myId)',
          )
          .order('created_at', ascending: true)
          .order('id', ascending: true),
    );

    final ids = rows.map((r) => r['id'].toString()).toList();
    if (ids.isEmpty) {
      throw StateError(
        'Match dengan pengguna ini tidak ditemukan. Mungkin sudah dihapus.',
      );
    }
    return ChatRoom(primaryMatchId: ids.first, matchIds: ids);
  }

  Future<List<ChatMessage>> getMessages(ChatRoom room, {int limit = 200}) async {
    final rows = await withRetry(
      () async => await _client
          .from('messages')
          .select()
          .inFilter('match_id', room.matchIds)
          .order('created_at', ascending: false)
          .limit(limit),
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<ChatMessage> sendMessage({
    required ChatRoom room,
    required String text,
  }) async {
    final myId = currentUserId;
    if (myId == null) {
      throw StateError('Sesi berakhir. Silakan login ulang.');
    }

    final row = await _client
        .from('messages')
        .insert({
          'match_id': room.primaryMatchId,
          'sender_id': myId,
          'content': text,
        })
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    return ChatMessage.fromMap(row);
  }

  RealtimeChannel subscribeToRoom({
    required ChatRoom room,
    required void Function(ChatMessage message) onMessage,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    final topic =
        'chat-${room.primaryMatchId}-${DateTime.now().microsecondsSinceEpoch}';

    return _client
        .channel(topic)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: room.primaryMatchId,
          ),
          callback: (payload) =>
              onMessage(ChatMessage.fromMap(payload.newRecord)),
        )
        .subscribe(onStatus);
  }

  RealtimeChannel subscribeToAnyIncomingMessage({
    required bool Function(String matchId) isMyMatch,
    required VoidCallback onChange,
  }) {
    final topic = 'inbox-$currentUserId-${DateTime.now().microsecondsSinceEpoch}';

    return _client
        .channel(topic)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final matchId = payload.newRecord['match_id']?.toString();
            if (matchId != null && isMyMatch(matchId)) onChange();
          },
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
