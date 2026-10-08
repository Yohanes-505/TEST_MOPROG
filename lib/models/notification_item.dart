import 'package:Meetcha/models/app_notification.dart';

/// satu baris riwayat notifikasi dari tabel notifications
/// beda sama [AppNotification]

class NotificationItem {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
  });

  AppNotification toAppNotification() {
    return AppNotification(
      type: type,
      title: title,
      body: body,
      relatedId: relatedId,
    );
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final rawType = map['type']?.toString() ?? '';
    final type = AppNotificationType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => AppNotificationType.unknown,
    );

    return NotificationItem(
      id: map['id'].toString(),
      type: type,
      title: map['title']?.toString() ?? 'Notifikasi',
      body: map['body']?.toString() ?? '',
      relatedId: map['related_id']?.toString(),
      isRead: map['is_read'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}