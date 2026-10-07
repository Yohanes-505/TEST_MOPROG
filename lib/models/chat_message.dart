enum MessageStatus { sending, offline, failed, sent, read }
class ChatMessage {
  static const String localPrefix = 'local-';

  final String id;
  final String matchId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.local({
    required String matchId,
    required String senderId,
    required String text,
  }) {
    final now = DateTime.now();
    return ChatMessage(
      id: '$localPrefix${now.microsecondsSinceEpoch}',
      matchId: matchId,
      senderId: senderId,
      text: text,
      createdAt: now,
      status: MessageStatus.sending,
    );
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      matchId: map['match_id'].toString(),
      senderId: map['sender_id'].toString(),
      text: (map['content'] ?? '').toString(),
      status: map['is_read'] == true ? MessageStatus.read : MessageStatus.sent,
      createdAt:
          DateTime.tryParse('${map['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }

  bool get isRead => status == MessageStatus.read;
  bool get isPending =>
      status == MessageStatus.sending ||
      status == MessageStatus.offline ||
      status == MessageStatus.failed;

  ChatMessage copyWith({MessageStatus? status}) {
    return ChatMessage(
      id: id,
      matchId: matchId,
      senderId: senderId,
      text: text,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}