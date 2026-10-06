import 'dart:async';

import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/models/chat_message.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/models/report_model.dart';
import 'package:bumble/services/match_chat_service.dart';
import 'package:bumble/utils/date_label.dart';
import 'package:bumble/utils/network_error.dart';
import 'package:bumble/widgets/block_confirm_dialog.dart';
import 'package:bumble/widgets/report_bottom_sheet.dart';
import 'package:bumble/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final ProfileModel matchProfile;

  const ChatScreen({super.key, required this.matchProfile});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const Duration _matchLifetime = Duration(hours: 24);

  final MatchChatService _service = const MatchChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final List<ChatMessage> _messages = [];

  ChatRoom? _room;
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  Timer? _expiryTicker;

  bool _isLoading = true;
  bool _isSending = false;
  bool _syncing = false;
  bool _realtimeDown = false;
  bool _disposed = false;
  int _channelGen = 0;
  String? _loadError;

  String? get _myId => _service.currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_realtimeDown) _syncSilently();
    });

    // Reload countdown buat waktu kadaluarsa
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _room?.matchedAt != null) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncSilently();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _expiryTicker?.cancel();
    _closeChannel();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _closeChannel() {
    _channelGen++; 
    final channel = _channel;
    _channel = null;
    if (channel != null) _service.unsubscribe(channel);
  }

  Future<void> _start() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _realtimeDown = false;
    });

    try {
      final room = await _service.openRoom(widget.matchProfile.id);
      if (!mounted) return;
      _room = room;
      _closeChannel();
      final gen = _channelGen;
      _channel = _service.subscribeToRoom(
        room: room,
        onMessage: _onIncomingMessage,
        onStatus: (status, error) => _onRealtimeStatus(gen, status, error),
      );

      final history = await _service.getMessages(room);
      if (!mounted) return;
      _applyHistory(history);
    } catch (e) {
      debugPrint('Gagal membuka chat: $e');
      if (!mounted) return;
      _room = null; 
      _closeChannel();
      setState(() {
        _isLoading = false;
        _loadError = friendlyError(e);
      });
    }
  }

  void _onRealtimeStatus(
    int gen,
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    if (!mounted || _disposed || gen != _channelGen) return;
    if (error != null) debugPrint('Realtime chat: $status ($error)');

    final ok = status == RealtimeSubscribeStatus.subscribed;
    if (_realtimeDown == ok) setState(() => _realtimeDown = !ok);
    if (ok) _syncSilently();
  }

  Future<void> _syncSilently() async {
    final room = _room;
    if (room == null || _syncing || !mounted) return;
    _syncing = true;
    try {
      final history = await _service.getMessages(room);
      if (!mounted) return;
      _applyHistory(history);
    } catch (e) {
      debugPrint('Sinkron chat gagal (diabaikan): $e');
    } finally {
      _syncing = false;
    }
  }

  void _applyHistory(List<ChatMessage> history) {
    final knownIds = history.map((m) => m.id).toSet();
    final merged = <ChatMessage>[
      ...history,
      for (final m in _messages)
        if (!knownIds.contains(m.id)) m,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _messages
        ..clear()
        ..addAll(merged);
      _isLoading = false;
      _loadError = null;
    });
  }

  void _onIncomingMessage(ChatMessage message) {
    if (!mounted || _disposed) return;
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages.insert(0, message));
  }

  Future<void> _sendMessage() async {
    final room = _room;
    final text = _messageController.text.trim();
    if (room == null || text.isEmpty || _isSending || _myId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final sent = await _service.sendMessage(room: room, text: text);
      if (!mounted) return;

      setState(() {
        if (!_messages.any((m) => m.id == sent.id)) _messages.insert(0, sent);
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Gagal mengirim pesan: $e');
      if (!mounted) return;

      if (_messageController.text.isEmpty) {
        _messageController.text = text;
        _messageController.selection =
            TextSelection.collapsed(offset: text.length);
      }

      if (e is TimeoutException) {
        _syncSilently();
        Get.snackbar(
          'Koneksi lambat',
          'Pesan belum terkonfirmasi. Cek riwayat chat sebelum mengirim ulang.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Gagal mengirim',
          friendlyError(e),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _inputFocus.requestFocus();
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _reportUser() {
    showReportBottomSheet(
      context: context,
      reportedUserId: widget.matchProfile.id,
      source: ReportSource.chat,
      chatRoomId: _room?.primaryMatchId,
    );
  }

  Future<void> _blockUser() async {
    final blocked = await showBlockConfirmDialog(
      context: context,
      blockedUserId: widget.matchProfile.id,
      blockedUserName: widget.matchProfile.name,
    );

    if (blocked == true && mounted) {
      // keluar dari chat room abis ngeblok
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _reportUser();
              if (value == 'block') _blockUser();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Laporkan'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Blokir'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          _buildConnectionBanner(),
          Expanded(child: _buildMessages()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // Ini buat nunjukkin berapa lama lagi sebelum matchnya kadaluarsa
  Duration? get _remaining {
    final at = _room?.matchedAt;
    if (at == null) return null;
    final left = at.add(_matchLifetime).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Widget _buildProfileHeader() {
    final profile = widget.matchProfile;
    final remaining = _remaining;
    final expired = remaining == Duration.zero;
    final urgent =
        remaining != null && !expired && remaining < const Duration(hours: 3);

    final expiryColor = expired
        ? AppColors.error
        : urgent
            ? AppColors.warning
            : AppColors.textSecondary;

    final nameLabel =
        profile.age != null ? '${profile.name}, ${profile.age}' : profile.name;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(photoUrl: profile.photoUrl, radius: 40),
          const SizedBox(height: 12),
          Text(
            nameLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (remaining != null) ...[
            const SizedBox(height: 2),
            Text(
              expired
                  ? 'Match kadaluarsa'
                  : '${formatRemaining(remaining)} lagi untuk mengirim pesan',
              style: TextStyle(fontSize: 13, color: expiryColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    if (!_realtimeDown || _loadError != null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.warningSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Koneksi realtime terputus. Mencoba menyambung ulang…',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: _start,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada pesan. Sapa dia duluan!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final myId = _myId;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final older = index + 1 < _messages.length ? _messages[index + 1] : null;
        final showDate =
            older == null || !isSameDay(message.createdAt, older.createdAt);

        return Column(
          children: [
            if (showDate) _DateChip(label: formatDayLabel(message.createdAt)),
            _MessageBubble(message: message, isMe: message.senderId == myId),
          ],
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocus,
                enabled: _room != null,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ketik pesan...',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send, color: AppColors.onPrimary, size: 20),
                onPressed: (_isSending || _room == null) ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatClock(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: (isMe ? AppColors.onPrimary : AppColors.textSecondary)
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}