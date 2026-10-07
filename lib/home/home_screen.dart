import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/screens/match_screen.dart';
import 'package:Meetcha/screens/subscription_screen.dart';
import 'package:Meetcha/services/block_service.dart';
import 'package:Meetcha/services/swipe_service.dart';
import 'package:Meetcha/widgets/match_dialog.dart';
import 'package:Meetcha/widgets/profile_card_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabaseClient = Supabase.instance.client;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProfileModel> dailyBrew = [];

  bool isLoading = true;

  final SwipeService _swipeService = const SwipeService();

  /// ID profil yang pilihannya sedang diproses.
  /// Digunakan untuk mencegah tap ganda.
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    fetchDailyBrew();
  }

  Future<void> fetchDailyBrew({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final myId = _supabaseClient.auth.currentUser?.id;

      if (myId == null) {
        throw StateError('Sesi berakhir. Silakan login ulang.');
      }

      final swiped = await _supabaseClient
          .from('swipes')
          .select('swiped_id')
          .eq('swiper_id', myId);

      final swipedIds = (swiped as List)
          .map((item) => item['swiped_id'].toString())
          .toList();

      // User yang saling block tidak ditampilkan lagi.
      final hiddenIds = await BlockService.getHiddenUserIds(myId);

      final excludedIds = {...swipedIds, ...hiddenIds}.toList();

      var query = _supabaseClient.from('profiles').select().neq('id', myId);

      if (excludedIds.isNotEmpty) {
        query = query.not('id', 'in', excludedIds);
      }

      // Ambil kandidat lebih banyak terlebih dahulu
      // agar Daily Brew dapat dibuat secara acak.
      final result = await query.limit(50);

      final candidates =
          (result as List).map((item) => ProfileModel.fromMap(item)).toList()
            ..shuffle();

      if (!mounted) return;

      setState(() {
        dailyBrew = candidates.take(dailyLimit).toList();

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching daily brew: $e');

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      Get.snackbar(
        'Tidak dapat memuat Daily Brew',
        'Coba lagi beberapa saat.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        backgroundColor: Colors.white,
        colorText: AppColors.textPrimary,
      );
    }
  }

  /// Dipanggil setelah exit animation kartu selesai.
  ///
  /// Return true:
  /// swipe berhasil dan kartu boleh tetap menghilang.
  ///
  /// Return false:
  /// swipe gagal / limit tercapai dan kartu akan
  /// dianimasikan kembali ke posisi awal.
  Future<bool> handleSwipe(ProfileModel profile, SwipeAction action) async {
    if (_busyIds.contains(profile.id)) {
      return false;
    }

    setState(() {
      _busyIds.add(profile.id);
    });

    try {
      final result = await _swipeService.submitDetailed(
        targetId: profile.id,
        action: action,
      );

      if (!mounted) {
        return true;
      }

      // Swipe berhasil disimpan.
      // Profil baru dihapus setelah exit animation selesai.
      setState(() {
        dailyBrew.removeWhere((item) => item.id == profile.id);
      });

      if (result.isMatch) {
        await showMatchDialog(profile);
      } else if (action == SwipeAction.like) {
        Get.snackbar(
          'Like terkirim',
          'Kamu menyukai ${profile.name}',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 16,
          backgroundColor: Colors.white,
          colorText: AppColors.textPrimary,
          duration: const Duration(seconds: 2),
        );
      }

      // Jika Daily Brew sudah habis,
      // refresh kembali data yang tersedia.
      if (mounted && dailyBrew.isEmpty) {
        await fetchDailyBrew(showLoader: false);
      }

      return true;
    } on SwipeLimitReachedException catch (e) {
      if (!mounted) {
        return false;
      }

      Get.defaultDialog(
        title: 'Limit Harian Tercapai',
        titleStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        middleText:
            '${e.toString()}\n\nUpgrade ke Premium/VIP untuk swipe tanpa batas!',
        middleTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
        backgroundColor: Colors.white,
        radius: 20,
        textConfirm: 'Lihat Paket',
        textCancel: 'Nanti',
        confirmTextColor: Colors.white,
        buttonColor: AppColors.matchaDeep,
        cancelTextColor: AppColors.textSecondary,
        onConfirm: () {
          Get.back();

          Get.to(
            () => const SubscriptionScreen(),
            transition: Transition.cupertino,
            duration: const Duration(milliseconds: 320),
          );
        },
      );

      return false;
    } catch (e) {
      Get.snackbar(
        'Gagal',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        backgroundColor: Colors.white,
        colorText: AppColors.textPrimary,
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(profile.id);
        });
      }
    }
  }

  void _openMatches() {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const MatchChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _HomeHeader(onNotificationTap: _openMatches),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      final slide =
                          Tween<Offset>(
                            begin: const Offset(0, 0.025),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: isLoading
                        ? const _LoadingState(key: ValueKey('loading'))
                        : dailyBrew.isEmpty
                        ? _EmptyState(
                            key: const ValueKey('empty'),
                            onRefresh: () => fetchDailyBrew(showLoader: true),
                          )
                        : _DailyBrewContent(
                            key: const ValueKey('content'),
                            profiles: dailyBrew,
                            busyIds: _busyIds,
                            onRefresh: () => fetchDailyBrew(showLoader: false),
                            onSwipe: handleSwipe,
                            onBlocked: (profile) {
                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                dailyBrew.removeWhere(
                                  (item) => item.id == profile.id,
                                );
                              });
                            },
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
}

class _HomeHeader extends StatelessWidget {
  final VoidCallback onNotificationTap;

  const _HomeHeader({required this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 18, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.matchaSoft.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset('images/logo_mark.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEETCHA',
                  style: TextStyle(
                    color: AppColors.brown,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Daily Brew',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                  ),
                ),
              ],
            ),
          ),
          // Tombol Akses Cepat Gift Shop & Inventory
          _HeaderButton(
            icon: Icons.store_rounded,
            tooltip: 'Gift Shop',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GiftShopScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: Icons.inventory_2_rounded,
            tooltip: 'Inventory Saya',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserInventoryScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Match & Pesan',
            onTap: onNotificationTap,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.borderSoft),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.045),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 22, color: AppColors.brown),
          ),
        ),
      ),
    );
  }
}

class _DailyBrewContent extends StatelessWidget {
  final List<ProfileModel> profiles;

  final Set<String> busyIds;

  final Future<void> Function() onRefresh;

  final Future<bool> Function(ProfileModel profile, SwipeAction action) onSwipe;

  final ValueChanged<ProfileModel> onBlocked;

  const _DailyBrewContent({
    super.key,
    required this.profiles,
    required this.busyIds,
    required this.onRefresh,
    required this.onSwipe,
    required this.onBlocked,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.matchaDeep,
      backgroundColor: Colors.white,
      displacement: 18,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your picks for today',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'A small batch, thoughtfully brewed for you.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      key: ValueKey(profiles.length),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.matchaSoft.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${profiles.length} left',
                        style: const TextStyle(
                          color: AppColors.matchaDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final profile = profiles[index];

              return RepaintBoundary(
                key: ValueKey(profile.id),
                child: _AnimatedDailyBrewCard(
                  profile: profile,
                  actionsEnabled: !busyIds.contains(profile.id),
                  onSwipe: (action) {
                    return onSwipe(profile, action);
                  },
                  onBlocked: () {
                    onBlocked(profile);
                  },
                ),
              );
            }, childCount: profiles.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class _AnimatedDailyBrewCard extends StatefulWidget {
  final ProfileModel profile;

  final bool actionsEnabled;

  final Future<bool> Function(SwipeAction action) onSwipe;

  final VoidCallback onBlocked;

  const _AnimatedDailyBrewCard({
    required this.profile,
    required this.actionsEnabled,
    required this.onSwipe,
    required this.onBlocked,
  });

  @override
  State<_AnimatedDailyBrewCard> createState() => _AnimatedDailyBrewCardState();
}

class _AnimatedDailyBrewCardState extends State<_AnimatedDailyBrewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _movement;

  late final Animation<double> _collapse;

  double _direction = 0;

  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );

    _movement = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.78, curve: Curves.easeInCubic),
    );

    _collapse = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 1, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss(SwipeAction action) async {
    if (_isDismissing || !widget.actionsEnabled) {
      return;
    }

    setState(() {
      _isDismissing = true;

      _direction = action == SwipeAction.like ? 1 : -1;
    });

    // Fase keluar kartu.
    await _controller.forward(from: 0);

    if (!mounted) return;

    final success = await widget.onSwipe(action);

    // Jika server menolak swipe,
    // misalnya limit harian tercapai,
    // kartu kembali dengan halus.
    if (!success && mounted) {
      await _controller.reverse();

      if (!mounted) return;

      setState(() {
        _isDismissing = false;
        _direction = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: ProfileCardWidget(
        profile: widget.profile,
        isFullCard: false,
        actionsEnabled: widget.actionsEnabled && !_isDismissing,
        onPass: () {
          _dismiss(SwipeAction.dislike);
        },
        onLike: () {
          _dismiss(SwipeAction.like);
        },
        onBlocked: widget.onBlocked,
      ),
      builder: (context, child) {
        final progress = _movement.value;

        final screenWidth = MediaQuery.sizeOf(context).width;

        // Pass bergerak ke kiri,
        // Like bergerak ke kanan.
        final horizontalOffset = screenWidth * 1.15 * _direction * progress;

        final verticalOffset = 10 * progress;

        // Rotasi tipis agar terasa natural,
        // tetapi tidak seperti kartu dilempar.
        final rotation = 0.045 * _direction * progress;

        final scale = 1 - (0.025 * progress);

        // Fade dimulai setelah kartu
        // mulai meninggalkan area layar.
        final fadeProgress = ((progress - 0.42) / 0.58)
            .clamp(0.0, 1.0)
            .toDouble();

        final opacity = 1 - fadeProgress;

        // Setelah kartu keluar,
        // ruang vertikal ikut menutup sehingga
        // kartu berikutnya naik dengan smooth.
        final heightFactor = (1 - _collapse.value).clamp(0.0, 1.0).toDouble();

        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: heightFactor,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(horizontalOffset, verticalOffset),
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 13, color: AppColors.matchaDeep),
            SizedBox(height: 16),
            Text(
              'Brewing your Daily Brew...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyState({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.matchaDeep,
      backgroundColor: Colors.white,
      onRefresh: onRefresh,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.13),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.matchaSoft.withValues(alpha: 0.58),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_cafe_rounded,
                size: 36,
                color: AppColors.matchaDeep,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Brew-mu habis untuk hari ini',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Kamu sudah melihat semua pilihan hari ini. Coba kembali lagi besok untuk Daily Brew baru.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () {
                onRefresh();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.matchaDeep,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text(
                'Muat ulang',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}