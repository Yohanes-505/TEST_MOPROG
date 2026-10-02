import 'package:bumble/models/profile_model.dart';

/// siapa lawan bicaranya + pesan terakhir (kalau sudah ada).
class MatchPreview {
  final ProfileModel profile;
  final DateTime? matchedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final List<String> matchIds;

  const MatchPreview({
    required this.profile,
    this.matchedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.matchIds = const [],
  });

  bool get hasMessages => lastMessage != null;
}
