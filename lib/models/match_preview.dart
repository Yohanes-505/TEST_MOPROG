import 'package:bumble/models/profile_model.dart';
import 'package:bumble/utils/match_expiry.dart';

/// siapa lawan bicaranya + pesan terakhir (kalau sudah ada).
class MatchPreview {
  final ProfileModel profile;
  final DateTime? matchedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageIsMine;
  final List<String> matchIds;
  final bool activityKnown;

  const MatchPreview({
    required this.profile,
    this.matchedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.matchIds = const [],
    this.activityKnown = true,
  });

  bool get hasMessages => lastMessage != null;

  Duration? get timeLeft =>
      matchTimeLeft(matchedAt: matchedAt, hasMessages: hasMessages);

  bool get isExpired => activityKnown && timeLeft == Duration.zero;
}
