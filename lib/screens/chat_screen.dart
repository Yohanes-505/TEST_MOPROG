import 'dart:async';
import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/models/chat_message.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/models/report_model.dart';
import 'package:Meetcha/services/match_chat_service.dart';
import 'package:Meetcha/services/notification_service.dart';
import 'package:Meetcha/utils/date_label.dart';
import 'package:Meetcha/utils/match_expiry.dart';
import 'package:Meetcha/utils/network_error.dart';
import 'package:Meetcha/widgets/block_confirm_dialog.dart';
import 'package:Meetcha/widgets/emoji_picker.dart';
import 'package:Meetcha/widgets/report_bottom_sheet.dart';
import 'package:Meetcha/widgets/user_avatar.dart';
import 'package:Meetcha/widgets/verified_badge.dart';
import 'package:flutter/cupertino.dart';
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
    final matchId = _room?.primaryMatchId;
    if (_inForeground) {
      if (matchId != null) {
        unawaited(setActiveChat(matchId));
        unawaited(clearChatNotification(matchId));
      }
      _syncSilently().then((_) {
        _exitIfExpired();
        _markIncomingAsRead();
        _processQueue();
      });
    } else {
      unawaited(setActiveChat(null));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(setActiveChat(null));
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
      unawaited(setActiveChat(room.primaryMatchId));
      unawaited(clearChatNotification(room.primaryMatchId));
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
            _messages[i] = _messages[i].copyWith(status: MessageStatus.read);
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
      final queued =
          m.status == MessageStatus.sending ||
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
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
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
        if (!didPop && _showEmoji) {
          setState(() => _showEmoji = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _buildConnectionBanner(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _buildExpiryBanner(),
            ),
            Expanded(child: _buildMessages()),
            _buildInputBar(),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _showEmoji
                  ? EmojiPickerPanel(
                      onEmojiSelected: _insertEmoji,
                      onBackspace: _deleteBeforeCursor,
                    )
                  : const SizedBox.shrink(),
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
      hasMessages: _messages.any((message) => !message.isPending),
    );
  }

  bool get _isExpired => _remaining == Duration.zero;

  PreferredSizeWidget _buildAppBar() {
    final profile = widget.matchProfile;

    final nameLabel = profile.age != null
        ? '${profile.name}, ${profile.age}'
        : profile.name;

    final city = (profile.city ?? '').trim();

    return AppBar(
      toolbarHeight: 72,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _HeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      titleSpacing: 2,
      title: Row(
        children: [
          UserAvatar(photoUrl: profile.photoUrl, radius: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nameLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15.5,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    if (profile.isFaceVerified) ...[
                      const SizedBox(width: 5),
                      const VerifiedBadge(size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  city.isNotEmpty ? city : 'Meetcha match',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Opsi',
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          position: PopupMenuPosition.under,
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 21,
              color: AppColors.textPrimary,
            ),
          ),
          onSelected: (value) {
            if (value == 'report') _reportUser();
            if (value == 'block') _blockUser();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: AppColors.error, size: 19),
                  SizedBox(width: 10),
                  Text('Laporkan'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block_rounded, color: AppColors.error, size: 19),
                  SizedBox(width: 10),
                  Text('Blokir'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildExpiryBanner() {
    final remaining = _remaining;

    if (remaining == null) {
      return const SizedBox.shrink();
    }

    final expired = remaining == Duration.zero;
    final urgent = !expired && remaining < const Duration(hours: 3);

    final backgroundColor = expired
        ? AppColors.errorSoft
        : urgent
        ? AppColors.warningSoft
        : AppColors.matchaSoft.withValues(alpha: 0.55);

    final foregroundColor = expired
        ? AppColors.error
        : urgent
        ? AppColors.warning
        : AppColors.matchaDeep;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              expired ? Icons.timer_off_outlined : Icons.schedule_rounded,
              size: 16,
              color: foregroundColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                expired
                    ? 'Match ini sudah kadaluarsa.'
                    : '${formatRemaining(remaining)} lagi untuk mengirim pesan pertama.',
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    if (!_realtimeDown || _loadError != null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.warningBorder),
        ),
        child: const Row(
          children: [
            CupertinoActivityIndicator(radius: 7, color: AppColors.warning),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Koneksi realtime terputus. Sedang mencoba menyambung ulang…',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const _ChatLoadingState();
    }

    if (_loadError != null) {
      return _ChatErrorState(message: _loadError!, onRetry: _start);
    }

    if (_messages.isEmpty) {
      return _EmptyChatState(profile: widget.matchProfile);
    }

    final myId = _myId;

    String? latestMineId;
    for (final message in _messages) {
      if (message.senderId == myId) {
        latestMineId = message.id;
        break;
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];

        final older = index + 1 < _messages.length
            ? _messages[index + 1]
            : null;

        final newer = index > 0 ? _messages[index - 1] : null;

        final showDate =
            older == null || !isSameDay(message.createdAt, older.createdAt);

        final isMe = message.senderId == myId;

        final sameSenderAsNewer =
            newer != null &&
            newer.senderId == message.senderId &&
            isSameDay(newer.createdAt, message.createdAt) &&
            newer.createdAt.difference(message.createdAt).abs() <
                const Duration(minutes: 3);

        final canOpenPendingActions =
            isMe &&
            (message.status == MessageStatus.offline ||
                message.status == MessageStatus.failed);

        return Column(
          children: [
            if (showDate) _DateChip(label: formatDayLabel(message.createdAt)),
            _MessageBubble(
              message: message,
              isMe: isMe,
              compactTop: sameSenderAsNewer,
              showStatusLabel: isMe && message.id == latestMineId,
              onTapPending: canOpenPendingActions
                  ? () => _showPendingActions(message)
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputBar() {
    final canUseInput = _room != null && !_isExpired;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        bottom: !_showEmoji,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              final canSend = canUseInput && hasText;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _EmojiToggleButton(
                            showEmoji: _showEmoji,
                            enabled: canUseInput,
                            onTap: _toggleEmoji,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _inputFocus,
                              enabled: canUseInput,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) {
                                if (canSend) _sendMessage();
                              },
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                height: 1.35,
                              ),
                              decoration: InputDecoration(
                                hintText: canUseInput
                                    ? 'Ketik pesan...'
                                    : 'Chat tidak tersedia',
                                hintStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13.5,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  4,
                                  13,
                                  14,
                                  12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  _SendButton(enabled: canSend, onTap: _sendMessage),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool compactTop;
  final bool showStatusLabel;
  final VoidCallback? onTapPending;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.compactTop,
    this.showStatusLabel = false,
    this.onTapPending,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth > 520 ? 360.0 : screenWidth * 0.74;

    final status = message.status;

    final needsAttention =
        status == MessageStatus.offline || status == MessageStatus.failed;

    final dimmed = isMe && (status == MessageStatus.sending || needsAttention);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: EdgeInsets.only(top: compactTop ? 1.5 : 3, bottom: 3),
      padding: const EdgeInsets.fromLTRB(13, 9, 11, 7),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.matchaDeep.withValues(alpha: dimmed ? 0.68 : 1)
            : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(17),
          topRight: const Radius.circular(17),
          bottomLeft: Radius.circular(isMe ? 17 : 5),
          bottomRight: Radius.circular(isMe ? 5 : 17),
        ),
        border: isMe
            ? status == MessageStatus.failed
                  ? Border.all(color: AppColors.error, width: 1.2)
                  : null
            : Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: isMe ? 0.035 : 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.36,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatClock(message.createdAt),
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.textSecondary.withValues(alpha: 0.78),
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
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(onTap: onTapPending, child: bubble),
          if (isMe && (showStatusLabel || needsAttention))
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 2, bottom: 2),
              child: GestureDetector(
                onTap: onTapPending,
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: needsAttention
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: _statusLabelColor(status),
                  ),
                ),
              ),
            ),
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
    final faded = Colors.white.withValues(alpha: 0.72);

    final IconData icon;
    final Color color;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.schedule_rounded;
        color = faded;
      case MessageStatus.offline:
        icon = Icons.cloud_off_rounded;
        color = faded;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = AppColors.errorSoft;
      case MessageStatus.sent:
        icon = Icons.done_all_rounded;
        color = faded;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = _readedColor;
    }

    return Semantics(
      label: _statusLabel(status),
      child: Icon(icon, size: 13, color: color),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.borderSoft, endIndent: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.borderSoft, indent: 12)),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final ProfileModel profile;

  const _EmptyChatState({required this.profile});

  @override
  Widget build(BuildContext context) {
    final firstName = profile.name.trim().split(' ').first;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: UserAvatar(photoUrl: profile.photoUrl, radius: 40),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.matchaDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 3),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Kamu match dengan $firstName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Mulai percakapan dengan sapaan sederhana. Kadang obrolan terbaik dimulai dari satu pesan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatLoadingState extends StatelessWidget {
  const _ChatLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: 13, color: AppColors.matchaDeep),
          SizedBox(height: 13),
          Text(
            'Loading conversation...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChatErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 27,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Percakapan belum bisa dibuka',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.matchaDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Icon(widget.icon, size: 17, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _EmojiToggleButton extends StatefulWidget {
  final bool showEmoji;
  final bool enabled;
  final VoidCallback onTap;

  const _EmojiToggleButton({
    required this.showEmoji,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_EmojiToggleButton> createState() => _EmojiToggleButtonState();
}

class _EmojiToggleButtonState extends State<_EmojiToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 44,
          height: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              widget.showEmoji
                  ? Icons.keyboard_alt_outlined
                  : Icons.emoji_emotions_outlined,
              key: ValueKey(widget.showEmoji),
              size: 21,
              color: widget.enabled
                  ? AppColors.textSecondary
                  : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: widget.enabled
                ? AppColors.matchaDeep
                : AppColors.surfaceMuted,
            shape: BoxShape.circle,
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AppColors.matchaDeep.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 20,
            color: widget.enabled ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
