import 'dart:async';

import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/models/app_notification.dart';
import 'package:Meetcha/models/notification_item.dart';
import 'package:Meetcha/services/notification_history_service.dart';
// `onNotificationTap` didefinisikan di notification_service.dart (bukan
// main.dart) -- main.dart cuma nge-assign isinya. Pakai ulang yang sama
// di sini biar tap notif dari riwayat & dari status bar HP konsisten.
import 'package:Meetcha/services/notification_service.dart'
    show onNotificationTap;
import 'package:Meetcha/utils/date_label.dart';
import 'package:flutter/material.dart';

/// Halaman "Notifikasi" biasa -- daftar riwayat match & pesan yang pernah
/// masuk, bukan langsung lompat ke Match & Chat kayak tombol lonceng
/// sebelumnya. Tap satu item nge-trigger alur navigasi yang SAMA kayak
/// pas notif di-tap dari status bar HP (lewat `onNotificationTap` yang
/// sama), jadi gak ada logika navigasi yang dobel.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationHistoryService _service = const NotificationHistoryService();

  List<NotificationItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.getMyNotifications();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _openItem(NotificationItem item) async {
    if (!item.isRead) {
      // Optimis: update tampilan dulu baru simpan ke server, biar
      // kerasa instan pas di-tap.
      setState(() {
        final index = _items.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _items[index] = NotificationItem(
            id: item.id,
            type: item.type,
            title: item.title,
            body: item.body,
            relatedId: item.relatedId,
            isRead: true,
            createdAt: item.createdAt,
          );
        }
      });
      unawaited(_service.markAsRead(item.id));
    }

    // Pakai ulang alur navigasi yang sama kayak pas notif di-tap dari
    // status bar (main.dart), biar konsisten: match -> Match & Chat,
    // message -> ChatScreen lawan bicaranya.
    onNotificationTap?.call(item.toAppNotification());
  }

  Future<void> _markAllRead() async {
    if (_items.every((i) => i.isRead)) return;
    setState(() {
      _items = _items
          .map((i) => NotificationItem(
                id: i.id,
                type: i.type,
                title: i.title,
                body: i.body,
                relatedId: i.relatedId,
                isRead: true,
                createdAt: i.createdAt,
              ))
          .toList();
    });
    await _service.markAllAsRead();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((i) => !i.isRead);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tandai semua dibaca'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Icon(Icons.notifications_none_rounded,
                            size: 48, color: AppColors.mist),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Belum ada notifikasi.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.borderSoft),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _NotificationTile(
                          item: item,
                          onTap: () => _openItem(item),
                        );
                      },
                    ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  IconData get _icon {
    switch (item.type) {
      case AppNotificationType.match:
        return Icons.favorite_rounded;
      case AppNotificationType.message:
        return Icons.chat_bubble_rounded;
      case AppNotificationType.unknown:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.isRead ? Colors.transparent : AppColors.matchaSoft.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.matchaSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 20, color: AppColors.matchaDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight:
                            item.isRead ? FontWeight.w600 : FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatChatListTime(item.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  if (!item.isRead) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.matchaDeep,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}