const Duration kMatchLifetime = Duration(hours: 24);

Duration? matchTimeLeft({
  DateTime? matchedAt,
  required bool hasMessages,
  DateTime? now,
}) {
  if (hasMessages || matchedAt == null) return null;
  final left = matchedAt.add(kMatchLifetime).difference(now ?? DateTime.now());
  return left.isNegative ? Duration.zero : left;
}
