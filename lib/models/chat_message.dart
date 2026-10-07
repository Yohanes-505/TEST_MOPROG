class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String text;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      matchId: map['match_id'].toString(),
      senderId: map['sender_id'].toString(),
      text: (map['content'] ?? '').toString(),
      isRead: map['is_read'] == true,
      createdAt:
          DateTime.tryParse('${map['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }
}
