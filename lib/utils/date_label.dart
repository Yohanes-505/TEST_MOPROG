bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _two(int n) => n.toString().padLeft(2, '0');

String formatClock(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String formatDayLabel(DateTime d) {
  final now = DateTime.now();
  if (isSameDay(d, now)) return 'Hari ini';
  if (isSameDay(d, now.subtract(const Duration(days: 1)))) return 'Kemarin';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

String formatChatListTime(DateTime d) {
  final now = DateTime.now();
  if (isSameDay(d, now)) return formatClock(d);
  if (isSameDay(d, now.subtract(const Duration(days: 1)))) return 'Kemarin';
  return '${_two(d.day)}/${_two(d.month)}';
}
