class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      senderId: map['sender_id'].toString(),
      receiverId: map['receiver_id'].toString(),
      text: (map['message'] ?? '').toString(),
      createdAt:
          DateTime.tryParse('${map['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }
}
