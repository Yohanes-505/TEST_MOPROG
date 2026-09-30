import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/models/chat_message.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/models/report_model.dart';
import 'package:bumble/services/match_chat_service.dart';
import 'package:bumble/utils/date_label.dart';
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

class _ChatScreenState extends State<ChatScreen> {
  final MatchChatService _service = const MatchChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final List<ChatMessage> _messages = [];
  RealtimeChannel? _channel;

  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;

  String? get _myId => _service.currentUserId;

  @override
  void initState() {
    super.initState();
    _channel = _service.subscribeToIncomingMessages(
      fromUserId: widget.matchProfile.id,
      onMessage: _onIncomingMessage,
    );
    _loadMessages();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _service.unsubscribe(channel);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final history = await _service.getMessages(widget.matchProfile.id);
      if (!mounted) return;

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
      });
    } catch (e) {
      debugPrint('Gagal memuat chat: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Pesan gagal dimuat.';
      });
    }
  }

  void _onIncomingMessage(ChatMessage message) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages.insert(0, message));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _myId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final sent = await _service.sendMessage(
        receiverId: widget.matchProfile.id,
        text: text,
      );
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
      Get.snackbar(
        'Gagal mengirim',
        'Pesan tidak terkirim. Periksa koneksi lalu coba lagi.',
        snackPosition: SnackPosition.BOTTOM,
      );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(photoUrl: widget.matchProfile.photoUrl, radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.matchProfile.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 1,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _reportUser();
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
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildInputBar(),
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
            Text(_loadError!,
                style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(
              onPressed: _loadMessages,
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
                onPressed: _isSending ? null : _sendMessage,
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
