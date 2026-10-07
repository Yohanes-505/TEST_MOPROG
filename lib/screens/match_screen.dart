import 'dart:async';

import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/models/match_preview.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/screens/chat_screen.dart';
import 'package:Meetcha/screens/likes_screen.dart';
import 'package:Meetcha/services/match_chat_service.dart';
import 'package:Meetcha/utils/date_label.dart';
import 'package:Meetcha/utils/network_error.dart';
import 'package:Meetcha/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
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

  List<MatchPreview> get _newMatches => _items
      .where(
        (item) => !item.isExpired && !item.hasMessages,
      )
      .toList();

  List<MatchPreview> get _conversations => _items
      .where(
        (item) => !item.isExpired && item.hasMessages,
      )
      .toList();

  @override
  void initState() {
    super.initState();

    MatchChatService.matchesChanged.addListener(
      _reloadQuietly,
    );

    _inboxChannel = _service.subscribeToAnyIncomingMessage(
      isMyMatch: (matchId) {
        return _items.any(
          (item) => item.matchIds.contains(matchId),
        );
      },
      onChange: _reloadQuietly,
    );

    _load(
      showSpinner: false,
    );

    _expiryTicker = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;

        if (!_items.any((item) => item.isExpired)) {
          return;
        }

        setState(() {});

        _load(
          showSpinner: false,
        );
      },
    );
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();

    MatchChatService.matchesChanged.removeListener(
      _reloadQuietly,
    );

    final channel = _inboxChannel;

    if (channel != null) {
      _service.unsubscribe(channel);
    }

    super.dispose();
  }

  void _reloadQuietly() {
    _load(
      showSpinner: false,
    );
  }

  Future<void> _load({
    bool showSpinner = true,
  }) async {
    final seq = ++_loadSeq;

    if (showSpinner && _items.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result =
          await _service.getMatchPreviews();

      if (!mounted || seq != _loadSeq) {
        return;
      }

      setState(() {
        _items = result;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint(
        'Gagal memuat match: $e',
      );

      if (!mounted || seq != _loadSeq) {
        return;
      }

      setState(() {
        _isLoading = false;

        if (_items.isEmpty) {
          _error = friendlyError(e);
        }
      });
    }
  }

  Future<void> _openChat(
    ProfileModel profile,
  ) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatScreen(
          matchProfile: profile,
        ),
      ),
    );

    if (mounted) {
      _load(
        showSpinner: false,
      );
    }
  }

  Future<void> _openLikes() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const LikesScreen(),
      ),
    );

    if (mounted) {
      _load(
        showSpinner: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const _PageHeader(),

                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.matchaDeep,
                    backgroundColor: Colors.white,
                    displacement: 18,
                    onRefresh: () => _load(
                      showSpinner: false,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(
                        milliseconds: 260,
                      ),
                      switchInCurve:
                          Curves.easeOutCubic,
                      switchOutCurve:
                          Curves.easeOutCubic,
                      transitionBuilder:
                          (
                        child,
                        animation,
                      ) {
                        final slide =
                            Tween<Offset>(
                          begin:
                              const Offset(
                            0,
                            0.015,
                          ),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves
                                .easeOutCubic,
                          ),
                        );

                        return FadeTransition(
                          opacity: animation,
                          child:
                              SlideTransition(
                            position: slide,
                            child: child,
                          ),
                        );
                      },
                      child: _buildBody(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        key: const ValueKey('loading'),
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 150),
          Center(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(
                  radius: 13,
                  color:
                      AppColors.matchaDeep,
                ),
                SizedBox(height: 14),
                Text(
                  'Loading your connections...',
                  style: TextStyle(
                    color: AppColors
                        .textSecondary,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        key: const ValueKey('error'),
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 28,
        ),
        children: [
          const SizedBox(height: 90),

          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: AppColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: AppColors.error,
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Belum bisa memuat match',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  AppColors.textPrimary,
              fontSize: 19,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: TextButton.icon(
              onPressed: () {
                _load();
              },
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),
              label: const Text(
                'Coba lagi',
              ),
              style:
                  TextButton.styleFrom(
                foregroundColor:
                    AppColors
                        .matchaDeep,
              ),
            ),
          ),
        ],
      );
    }

    final newMatches = _newMatches;
    final conversations =
        _conversations;

    return ListView(
      key: const ValueKey('content'),
      physics:
          const BouncingScrollPhysics(
        parent:
            AlwaysScrollableScrollPhysics(),
      ),
      padding:
          const EdgeInsets.only(
        bottom: 28,
      ),
      children: [
        _buildLikesEntry(),

        _SectionHeader(
          title: 'Match Baru',
          count: newMatches.length,
        ),

        if (newMatches.isEmpty)
          const _EmptyNewMatchState()
        else
          SizedBox(
            height: 102,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              itemCount:
                  newMatches.length,
              separatorBuilder:
                  (
                context,
                index,
              ) =>
                      const SizedBox(
                width: 6,
              ),
              itemBuilder:
                  (
                context,
                index,
              ) {
                final item =
                    newMatches[index];

                return _NewMatchItem(
                  item: item,
                  onTap: () {
                    _openChat(
                      item.profile,
                    );
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 8),

        _SectionHeader(
          title: 'Pesan',
          count:
              conversations.length,
        ),

        if (conversations.isEmpty)
          const _EmptyConversationState()
        else
          ...conversations.map(
            (item) {
              return _ConversationItem(
                item: item,
                onTap: () {
                  _openChat(
                    item.profile,
                  );
                },
              );
            },
          ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLikesEntry() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        6,
        20,
        20,
      ),
      child: _Pressable(
        onTap: _openLikes,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: AppColors.matchaSoft
                .withValues(
              alpha: 0.64,
            ),
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color: AppColors
                  .primaryBorder
                  .withValues(
                alpha: 0.82,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.94,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 20,
                  color: AppColors
                      .matchaDeep,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Orang yang menyukaimu',
                      style: TextStyle(
                        color: AppColors
                            .textPrimary,
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lihat siapa yang sudah tertarik denganmu.',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors
                            .textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                width: 30,
                height: 30,
                decoration:
                    const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors
                      .matchaDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader
    extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Matches',
            style: TextStyle(
              color:
                  AppColors.textPrimary,
              fontSize: 27,
              height: 1.02,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Connections worth brewing',
            style: TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader
    extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                color: AppColors
                    .textPrimary,
                fontSize: 16.5,
                fontWeight:
                    FontWeight.w800,
                letterSpacing:
                    -0.25,
              ),
            ),
          ),

          AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            child: Container(
              key: ValueKey(count),
              constraints:
                  const BoxConstraints(
                minWidth: 30,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 9,
                vertical: 4,
              ),
              decoration:
                  BoxDecoration(
                color: AppColors
                    .surfaceMuted
                    .withValues(
                  alpha: 0.82,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  999,
                ),
              ),
              child: Text(
                '$count',
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: AppColors
                      .textSecondary,
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMatchItem
    extends StatelessWidget {
  final MatchPreview item;
  final VoidCallback onTap;

  const _NewMatchItem({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile =
        item.profile;

    return _Pressable(
      onTap: onTap,
      scale: 0.96,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Stack(
              clipBehavior:
                  Clip.none,
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(
                    2.3,
                  ),
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border: Border.all(
                      color:
                          AppColors.matcha,
                      width: 1.8,
                    ),
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets
                            .all(
                      2,
                    ),
                    decoration:
                        const BoxDecoration(
                      color:
                          Colors.white,
                      shape:
                          BoxShape.circle,
                    ),
                    child: UserAvatar(
                      photoUrl:
                          profile.photoUrl,
                      radius: 27,
                    ),
                  ),
                ),

                Positioned(
                  right: 1,
                  bottom: 3,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .matchaDeep,
                      shape:
                          BoxShape.circle,
                      border:
                          Border.all(
                        color: AppColors
                            .background,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                Flexible(
                  child: Text(
                    profile.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color: AppColors
                          .textPrimary,
                      fontSize: 11.5,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                ),

                if (profile
                    .isFaceVerified) ...[
                  const SizedBox(
                    width: 3,
                  ),
                  const VerifiedBadge(
                    size: 12,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationItem
    extends StatelessWidget {
  final MatchPreview item;
  final VoidCallback onTap;

  const _ConversationItem({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile =
        item.profile;

    final at =
        item.lastMessageAt;

    final preview =
        '${item.lastMessageIsMine ? 'Kamu: ' : ''}${item.lastMessage ?? ''}';

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        9,
      ),
      child: _Pressable(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.fromLTRB(
            13,
            12,
            11,
            12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border: Border.all(
              color:
                  AppColors.borderSoft,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink
                    .withValues(
                  alpha: 0.025,
                ),
                blurRadius: 14,
                offset:
                    const Offset(
                  0,
                  4,
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              UserAvatar(
                photoUrl:
                    profile.photoUrl,
                radius: 25,
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color: AppColors
                                  .textPrimary,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),

                        if (profile
                            .isFaceVerified) ...[
                          const SizedBox(
                            width: 4,
                          ),
                          const VerifiedBadge(
                            size: 13,
                          ),
                        ],

                        const Spacer(),

                        if (at != null)
                          Text(
                            formatChatListTime(
                              at,
                            ),
                            style:
                                const TextStyle(
                              color: AppColors
                                  .textSecondary,
                              fontSize: 10,
                              fontWeight:
                                  FontWeight
                                      .w500,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color: AppColors
                                  .textSecondary,
                              fontSize: 12,
                              fontWeight:
                                  item.lastMessageIsMine
                                      ? FontWeight
                                          .w500
                                      : FontWeight
                                          .w600,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 6,
                        ),

                        const Icon(
                          Icons
                              .chevron_right_rounded,
                          size: 17,
                          color: AppColors
                              .border,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNewMatchState
    extends StatelessWidget {
  const _EmptyNewMatchState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16,
      ),
      child: Container(
        height: 96,
        decoration:
            BoxDecoration(
          color: AppColors
              .surfaceMuted
              .withValues(
            alpha: 0.52,
          ),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: const Center(
          child: Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Text(
              'Belum ada match baru.\nDaily Brew berikutnya mungkin orangnya.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: AppColors
                    .textSecondary,
                fontSize: 11.8,
                height: 1.4,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyConversationState
    extends StatelessWidget {
  const _EmptyConversationState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 22,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            19,
          ),
          border: Border.all(
            color:
                AppColors.borderSoft,
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons
                  .chat_bubble_outline_rounded,
              size: 27,
              color:
                  AppColors.matcha,
            ),

            SizedBox(height: 9),

            Text(
              'Belum ada percakapan',
              style: TextStyle(
                color: AppColors
                    .textPrimary,
                fontSize: 14.5,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            SizedBox(height: 4),

            Text(
              'Sapa match barumu duluan dan mulai percakapan.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: AppColors
                    .textSecondary,
                fontSize: 11.8,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pressable
    extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const _Pressable({
    required this.child,
    required this.onTap,
    this.scale = 0.98,
  });

  @override
  State<_Pressable> createState() =>
      _PressableState();
}

class _PressableState
    extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(
    bool value,
  ) {
    if (_pressed == value) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTapDown: (_) {
        _setPressed(true);
      },
      onTapCancel: () {
        _setPressed(false);
      },
      onTapUp: (_) {
        _setPressed(false);
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed
            ? widget.scale
            : 1,
        duration:
            const Duration(
          milliseconds: 100,
        ),
        curve:
            Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}