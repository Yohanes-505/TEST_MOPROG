import 'dart:async';
import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/models/chat_message.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/models/report_model.dart';
import 'package:bumble/services/match_chat_service.dart';
import 'package:bumble/utils/date_label.dart';
import 'package:bumble/utils/match_expiry.dart';
import 'package:bumble/utils/network_error.dart';
import 'package:bumble/widgets/block_confirm_dialog.dart';
import 'package:bumble/widgets/emoji_picker.dart';
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
  bool _queueRunning = false;
  bool _inForeground = true;
  bool _markingRead = false;
  bool _markAgain = false;
  bool _syncing = false;
  bool _realtimeDown = false;
  bool _disposed = false;
  bool _showEmoji = false;
  bool _historyLoaded = false;
  bool _expiryHandled = false;
  int _channelGen = 0;
  String? _loadError;

  String? get _myId => _service.currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputFocus.addListener(_onInputFocusChanged);
    _start();

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_realtimeDown) _syncSilently();
      if (_hasOfflineMessages) _processQueue();
    });

    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted || _expiryHandled) return;
      if (_isExpired) {
        await _syncSilently();
        _exitIfExpired();
      } else if (_remaining != null) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (_inForeground) {
      _syncSilently().then((_) {
        _exitIfExpired();
        _markIncomingAsRead();
        _processQueue();
      });
    }
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
    _inputFocus.removeListener(_onInputFocusChanged);
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
        onMessageUpdated: _onMessageUpdated,
        onStatus: (status, error) => _onRealtimeStatus(gen, status, error),
      );

      final history = await _service.getMessages(room);
      if (!mounted) return;
      _applyHistory(history);
      _exitIfExpired();
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
    if (ok) _syncSilently().then((_) => _processQueue());
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
      _historyLoaded = true;
    });
    _markIncomingAsRead();
  }

  void _exitIfExpired() {
    if (_expiryHandled || !mounted || !_isExpired) return;
    _expiryHandled = true;

    _expiryTicker?.cancel();
    _pollTimer?.cancel();
    _closeChannel();
    unawaited(_service.purgeExpiredMatches());

    final name = widget.matchProfile.name;
    Navigator.of(context).pop();
    Get.snackbar(
      'Match kadaluarsa',
      'Match dengan $name dihapus karena belum ada pesan dalam '
          '${kMatchLifetime.inHours} jam.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _onIncomingMessage(ChatMessage message) {
    if (!mounted || _disposed) return;
    if (_messages.any((m) => m.id == message.id)) return;
    if (message.senderId == _myId) {
      final i = _messages.indexWhere(
        (m) => m.status == MessageStatus.sending && m.text == message.text,
      );
      if (i != -1) {
        setState(() => _messages[i] = message);
        return;
      }
    }

    setState(() => _messages.insert(0, message));
    _markIncomingAsRead();
  }

  void _onMessageUpdated(ChatMessage message) {
    if (!mounted || _disposed) return;
    final i = _messages.indexWhere((m) => m.id == message.id);
    if (i == -1 || _messages[i].isRead) return;
    if (message.isRead) {
      setState(
        () => _messages[i] = _messages[i].copyWith(status: MessageStatus.read),
      );
    }
  }

  bool get _hasOfflineMessages =>
      _messages.any((m) => m.status == MessageStatus.offline);

  Future<void> _markIncomingAsRead() async {
    final room = _room;
    final myId = _myId;
    if (room == null || myId == null || !mounted || !_inForeground) return;
    if (_markingRead) {
      _markAgain = true;
      return;
    }

    final unreadIds = _messages
        .where((m) => m.senderId != myId && !m.isRead)
        .map((m) => m.id)
        .toSet();
    if (unreadIds.isEmpty) return;

    _markingRead = true;
    try {
      await _service.markMessagesRead(room);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          if (unreadIds.contains(_messages[i].id)) {
            _messages[i] =
                _messages[i].copyWith(status: MessageStatus.read);
          }
        }
      });
      if (_markAgain) {
        _markAgain = false;
        unawaited(_markIncomingAsRead());
      }
    } catch (e) {
      _markAgain = false;
      debugPrint('Gagal menandai pesan dibaca: $e');
    } finally {
      _markingRead = false;
    }
  }

  void _sendMessage() {
    final room = _room;
    final myId = _myId;
    final text = _messageController.text.trim();
    if (room == null || text.isEmpty || myId == null) return;
    if (_isExpired) {
      _exitIfExpired();
      return;
    }

    _messageController.clear();
    final local = ChatMessage.local(
      matchId: room.primaryMatchId,
      senderId: myId,
      text: text,
    );
    setState(() => _messages.insert(0, local));
    _scrollToBottom();
    if (!_showEmoji) _inputFocus.requestFocus();
    _processQueue();
  }

  ChatMessage? _nextQueued() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      final queued = m.status == MessageStatus.sending ||
          m.status == MessageStatus.offline;
      if (queued && m.id.startsWith(ChatMessage.localPrefix)) return m;
    }
    return null;
  }

  Future<void> _processQueue() async {
    if (_queueRunning) return;
    _queueRunning = true;
    try {
      while (mounted && !_disposed) {
        final room = _room;
        final next = room == null ? null : _nextQueued();
        if (room == null || next == null) break;

        _setStatus(next.id, MessageStatus.sending);
        try {
          final sent = await _service.sendMessage(room: room, text: next.text);
          if (!mounted) return;
          _resolveLocal(next.id, sent);
        } catch (e) {
          debugPrint('Gagal mengirim pesan: $e');
          if (!mounted) return;

          if (e is TimeoutException) {
            _setStatus(next.id, MessageStatus.failed);
            _markQueuedOffline();
            _syncSilently();
            Get.snackbar(
              'Koneksi lambat',
              'Pesan belum terkonfirmasi. Cek riwayat chat sebelum '
                  'mengirim ulang.',
              snackPosition: SnackPosition.BOTTOM,
            );
            break;
          }

          if (isNetworkError(e)) {
            _setStatus(next.id, MessageStatus.offline);
            _markQueuedOffline();
            break;
          }

          _setStatus(next.id, MessageStatus.failed);
          Get.snackbar(
            'Gagal mengirim',
            friendlyError(e),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } finally {
      _queueRunning = false;
    }
  }

  void _setStatus(String id, MessageStatus status) {
    if (!mounted) return;
    final i = _messages.indexWhere((m) => m.id == id);
    if (i == -1 || _messages[i].status == status) return;
    setState(() => _messages[i] = _messages[i].copyWith(status: status));
  }

  void _markQueuedOffline() {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final m = _messages[i];
        if (m.status == MessageStatus.sending &&
            m.id.startsWith(ChatMessage.localPrefix)) {
          _messages[i] = m.copyWith(status: MessageStatus.offline);
        }
      }
    });
  }

  void _resolveLocal(String localId, ChatMessage sent) {
    final alreadyThere = _messages.any((m) => m.id == sent.id);
    final i = _messages.indexWhere((m) => m.id == localId);
    setState(() {
      if (i != -1) {
        if (alreadyThere) {
          _messages.removeAt(i);
        } else {
          _messages[i] = sent;
        }
      } else if (!alreadyThere) {
        _messages.insert(0, sent);
      }
      _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  void _retry(ChatMessage message) {
    _setStatus(message.id, MessageStatus.sending);
    _processQueue();
  }

  void _discard(ChatMessage message) {
    if (!mounted) return;
    setState(() => _messages.removeWhere((m) => m.id == message.id));
  }

  void _showPendingActions(ChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Kirim ulang'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _retry(message);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Hapus pesan',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _discard(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // BAGIAN EMOJIII
  void _onInputFocusChanged() {
    if (_inputFocus.hasFocus && _showEmoji) {
      setState(() => _showEmoji = false);
    }
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _inputFocus.requestFocus();
    } else {
      _inputFocus.unfocus();
      setState(() => _showEmoji = true);
    }
  }

  void _insertEmoji(String emoji) {
    final value = _messageController.value;
    final text = value.text;
    final sel = value.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;

    _messageController.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _deleteBeforeCursor() {
    final value = _messageController.value;
    final text = value.text;
    final sel = value.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;

    if (start != end) {
      _messageController.value = TextEditingValue(
        text: text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
      return;
    }
    if (start == 0) return;

    final before = text.substring(0, start).characters.skipLast(1).toString();
    _messageController.value = TextEditingValue(
      text: before + text.substring(start),
      selection: TextSelection.collapsed(offset: before.length),
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
    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showEmoji) setState(() => _showEmoji = false);
      },
      child: Scaffold(
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
            if (_showEmoji)
              EmojiPickerPanel(
                onEmojiSelected: _insertEmoji,
                onBackspace: _deleteBeforeCursor,
              ),
          ],
        ),
      ),
    );
  }

  Duration? get _remaining {
    if (!_historyLoaded) return null;
    return matchTimeLeft(
      matchedAt: _room?.matchedAt,
      hasMessages: _messages.any((m) => !m.isPending),
    );
  }

  bool get _isExpired => _remaining == Duration.zero;

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
    String? latestMineId;
    for (final m in _messages) {
      if (m.senderId == myId) {
        latestMineId = m.id;
        break;
      }
    }

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
        final isMe = message.senderId == myId;

        return Column(
          children: [
            if (showDate) _DateChip(label: formatDayLabel(message.createdAt)),
            _MessageBubble(
              message: message,
              isMe: isMe,
              showStatusLabel: isMe && message.id == latestMineId,
              onTapPending: isMe &&
                      (message.status == MessageStatus.offline ||
                          message.status == MessageStatus.failed)
                  ? () => _showPendingActions(message)
                  : null,
            ),
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
        bottom: !_showEmoji,
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
                  prefixIcon: IconButton(
                    tooltip: _showEmoji ? 'Tampilkan keyboard' : 'Pilih emoji',
                    icon: Icon(
                      _showEmoji
                          ? Icons.keyboard_alt_outlined
                          : Icons.emoji_emotions_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: _room == null ? null : _toggleEmoji,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 44, minHeight: 40),
                  contentPadding:
                      const EdgeInsets.fromLTRB(0, 10, 16, 10),
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
                icon: const Icon(
                  Icons.send,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
                onPressed: _room == null ? null : _sendMessage,
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

  final bool showStatusLabel;
  final VoidCallback? onTapPending;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.showStatusLabel = false,
    this.onTapPending,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    final status = message.status;
    final needsAttention =
        status == MessageStatus.offline || status == MessageStatus.failed;
    final dimmed = isMe && (status == MessageStatus.sending || needsAttention);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: dimmed ? 0.65 : 1)
            : AppColors.surfaceMuted,
        border: isMe && status == MessageStatus.failed
            ? Border.all(color: AppColors.error, width: 1.5)
            : null,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatClock(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: (isMe ? AppColors.onPrimary : AppColors.textSecondary)
                      .withValues(alpha: 0.7),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _StatusIcon(status: status),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(onTap: onTapPending, child: bubble),
          if (isMe && (showStatusLabel || needsAttention))
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 2),
              child: GestureDetector(
                onTap: onTapPending,
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        needsAttention ? FontWeight.w600 : FontWeight.w400,
                    color: _statusLabelColor(status),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

const Color _readedColor = Color(0xFF7FDBFF);

String _statusLabel(MessageStatus status) {
  switch (status) {
    case MessageStatus.sending:
      return 'Mengirim…';
    case MessageStatus.offline:
      return 'Di luar jaringan · akan dikirim otomatis';
    case MessageStatus.failed:
      return 'Gagal terkirim · ketuk untuk opsi';
    case MessageStatus.sent:
      return 'Terkirim';
    case MessageStatus.read:
      return 'Dibaca';
  }
}

Color _statusLabelColor(MessageStatus status) {
  switch (status) {
    case MessageStatus.sending:
    case MessageStatus.sent:
      return AppColors.textSecondary;
    case MessageStatus.offline:
      return AppColors.warning;
    case MessageStatus.failed:
      return AppColors.error;
    case MessageStatus.read:
      return AppColors.matchaDeep;
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final faded = AppColors.onPrimary.withValues(alpha: 0.75);

    final IconData icon;
    final Color color;
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.schedule;
        color = faded;
      case MessageStatus.offline:
        icon = Icons.done;
        color = faded;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = AppColors.errorSoft;
      case MessageStatus.sent:
        icon = Icons.done_all;
        color = faded;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = _readedColor;
    }

    return Semantics(
      label: _statusLabel(status),
      child: Icon(icon, size: 14, color: color),
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