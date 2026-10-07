import 'dart:async';

import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/models/match_preview.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/screens/chat_screen.dart';
import 'package:bumble/screens/likes_screen.dart';
import 'package:bumble/services/match_chat_service.dart';
import 'package:bumble/utils/date_label.dart';
import 'package:bumble/utils/network_error.dart';
import 'package:bumble/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchChatScreen extends StatefulWidget {
  const MatchChatScreen({super.key});

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen> {
  final MatchChatService _service = const MatchChatService();

  List<MatchPreview> _items = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _inboxChannel;
  Timer? _expiryTicker;

  int _loadSeq = 0;

  List<MatchPreview> get _newMatches =>
      _items.where((m) => !m.isExpired && !m.hasMessages).toList();

  /// Match yang sudah ada percakapannya.
  List<MatchPreview> get _conversations =>
      _items.where((m) => !m.isExpired && m.hasMessages).toList();

  @override
  void initState() {
    super.initState();
    MatchChatService.matchesChanged.addListener(_reloadQuietly);
    _inboxChannel = _service.subscribeToAnyIncomingMessage(
      isMyMatch: (matchId) => _items.any((m) => m.matchIds.contains(matchId)),
      onChange: _reloadQuietly,
    );
    _load(showSpinner: false);
    _expiryTicker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || !_items.any((m) => m.isExpired)) return;
      setState(() {});
      _load(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    MatchChatService.matchesChanged.removeListener(_reloadQuietly);
    final channel = _inboxChannel;
    if (channel != null) _service.unsubscribe(channel);
    super.dispose();
  }

  void _reloadQuietly() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    final seq = ++_loadSeq;

    if (showSpinner && _items.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _service.getMatchPreviews();
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _items = result;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Gagal memuat match: $e');
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _isLoading = false;
        if (_items.isEmpty) _error = friendlyError(e);
      });
    }
  }

  Future<void> _openChat(ProfileModel profile) async {
    await Get.to(() => ChatScreen(matchProfile: profile));
    if (mounted) _load(showSpinner: false);
  }

  Future<void> _openLikes() async {
    await Get.to(() => const LikesScreen());
    if (mounted) _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Match & Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(showSpinner: false),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 160),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ),
        ],
      );
    }

    final newMatches = _newMatches;
    final conversations = _conversations;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildLikesEntry(),

        // 1. Match baru (belum pernah chat)
        const _SectionTitle('Match Baru', color: AppColors.primaryDeep),
        SizedBox(
          height: 104,
          child: newMatches.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada match baru.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: newMatches.length,
                  itemBuilder: (context, index) =>
                      _buildNewMatchItem(newMatches[index].profile),
                ),
        ),
        const Divider(thickness: 1, color: Colors.black12),

        // 2. Percakapan
        const _SectionTitle('Pesan'),
        if (conversations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Belum ada percakapan aktif.\nSapa match barumu duluan!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...conversations.map(_buildConversationTile),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLikesEntry() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openLikes,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.favorite, color: AppColors.primaryDeep),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Orang yang menyukaimu',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewMatchItem(ProfileModel profile) {
    return GestureDetector(
      onTap: () => _openChat(profile),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: UserAvatar(photoUrl: profile.photoUrl, radius: 30),
              ),
              const SizedBox(height: 4),
              Text(
                profile.name,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(MatchPreview item) {
    final at = item.lastMessageAt;
    final preview =
        '${item.lastMessageIsMine ? 'Kamu: ' : ''}${item.lastMessage ?? ''}';

    return ListTile(
      leading: UserAvatar(photoUrl: item.profile.photoUrl, radius: 28),
      title: Text(
        item.profile.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: at == null
          ? null
          : Text(
              formatChatListTime(at),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
      onTap: () => _openChat(item.profile),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color? color;

  const _SectionTitle(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
