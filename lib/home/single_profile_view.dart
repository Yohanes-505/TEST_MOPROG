import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/models/report_model.dart';
import 'package:Meetcha/services/swipe_service.dart';
import 'package:Meetcha/widgets/block_confirm_dialog.dart';
import 'package:Meetcha/widgets/report_bottom_sheet.dart';
import 'package:Meetcha/widgets/verified_badge.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mode tampilan Home: daftar scroll (lama) atau 1 profil per layar (baru).
enum HomeViewMode { scroll, single }

/// Tampilan 1 profil sekaligus, ala "Suggested" di Coffee Meets Bagel.
///
/// Widget ini hanya menampilkan UI. Logika swipe (limit harian, match,
/// snackbar) tetap ada di `HomeScreen.handleSwipe`, jadi tidak diduplikasi.
class SingleProfileView extends StatefulWidget {
  final ProfileModel profile;

  /// Jumlah profil yang tersisa (termasuk yang sedang tampil).
  final int remaining;

  final bool actionsEnabled;

  final Future<bool> Function(SwipeAction action) onSwipe;

  final VoidCallback onBlocked;

  final Future<void> Function() onRefresh;

  const SingleProfileView({
    super.key,
    required this.profile,
    required this.remaining,
    required this.actionsEnabled,
    required this.onSwipe,
    required this.onBlocked,
    required this.onRefresh,
  });

  @override
  State<SingleProfileView> createState() => _SingleProfileViewState();
}

class _SingleProfileViewState extends State<SingleProfileView>
    with SingleTickerProviderStateMixin {
  final PageController _photoController = PageController();
  int _currentPhoto = 0;

  // Animasi Like / Pass:
  //  0.00 - 0.35  stempel "LIKE" / "PASS" muncul (membesar lalu mengecil)
  //  0.50 - 1.00  kartu meluncur keluar (kanan = Like, kiri = Pass)
  late final AnimationController _anim;
  late final Animation<double> _stampScale;
  late final Animation<double> _stampFade;
  late final Animation<double> _exit;

  SwipeAction? _action;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _stampScale = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0, 0.35, curve: Curves.easeOutBack),
    );
    _stampFade = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0, 0.2, curve: Curves.easeOut),
    );
    _exit = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.5, 1, curve: Curves.easeInCubic),
    );
  }

  Future<void> _handleAction(SwipeAction action) async {
    if (_isAnimating || !widget.actionsEnabled) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isAnimating = true;
      _action = action;
    });

    await _anim.forward(from: 0);
    if (!mounted) return;

    final success = await widget.onSwipe(action);

    // Kalau ditolak (mis. limit harian tercapai), kartu kembali.
    if (!success && mounted) {
      await _anim.reverse();
      if (!mounted) return;
      setState(() {
        _isAnimating = false;
        _action = null;
      });
    }
  }

  /// Geser + putar + pudarkan konten saat fase keluar.
  Widget _applyExit(Widget child) {
    final dir = _action == SwipeAction.like ? 1.0 : -1.0;
    final t = _exit.value;
    final width = MediaQuery.sizeOf(context).width;

    return Opacity(
      opacity: (1 - ((t - 0.35) / 0.65)).clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(width * 1.1 * dir * t, 20 * t),
        child: Transform.rotate(angle: 0.07 * dir * t, child: child),
      ),
    );
  }

  Widget _buildStamp() {
    final action = _action;
    if (action == null) return const SizedBox.shrink();

    final isLike = action == SwipeAction.like;
    final color = isLike ? AppColors.matcha : AppColors.error;

    return Positioned(
      top: 64,
      left: isLike ? 22 : null,
      right: isLike ? null : 22,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            return Opacity(
              opacity: _stampFade.value.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: isLike ? -0.22 : 0.22,
                child: Transform.scale(
                  scale: 1.7 - (0.7 * _stampScale.value),
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 4),
            ),
            child: Text(
              isLike ? 'LIKE' : 'PASS',
              style: TextStyle(
                color: color,
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _photoController.dispose();
    super.dispose();
  }

  void _previousPhoto() {
    _photoController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextPhoto() {
    _photoController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _report() {
    showReportBottomSheet(
      context: context,
      reportedUserId: widget.profile.id,
      source: ReportSource.profile,
    );
  }

  Future<void> _block() async {
    final blocked = await showBlockConfirmDialog(
      context: context,
      blockedUserId: widget.profile.id,
      blockedUserName: widget.profile.name,
    );

    if (blocked == true) {
      widget.onBlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.matchaDeep,
          backgroundColor: Colors.white,
          onRefresh: widget.onRefresh,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            // Ruang bawah supaya konten tidak tertutup tombol Pass/Like.
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, child) => _applyExit(child!),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    widget.remaining > 1
                        ? '${widget.remaining} picks left today'
                        : 'Last pick for today',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildPhoto(),
                const SizedBox(height: 14),
                _buildInfoCard(),
              ],
            ),
            ),
          ),
        ),

        // Tombol melayang: Pass di kiri, Like di kanan.
        Positioned(
          left: 28,
          bottom: 22,
          child: _RoundActionButton(
            icon: Icons.close_rounded,
            iconColor: AppColors.textPrimary,
            backgroundColor: Colors.white,
            enabled: widget.actionsEnabled && !_isAnimating,
            tooltip: 'Pass',
            onTap: () => _handleAction(SwipeAction.dislike),
          ),
        ),
        Positioned(
          right: 28,
          bottom: 22,
          child: _RoundActionButton(
            icon: Icons.favorite_rounded,
            iconColor: Colors.white,
            backgroundColor: AppColors.matchaDeep,
            enabled: widget.actionsEnabled && !_isAnimating,
            tooltip: 'Like',
            onTap: () => _handleAction(SwipeAction.like),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoto() {
    final photos = widget.profile.photoUrls;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photos.isEmpty)
                _placeholder()
              else
                PageView.builder(
                  controller: _photoController,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _currentPhoto = i),
                  itemBuilder: (_, i) => _networkPhoto(photos[i]),
                ),

              // Tap kiri / kanan untuk ganti foto.
              if (photos.length > 1)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _currentPhoto > 0 ? _previousPhoto : null,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _currentPhoto < photos.length - 1
                            ? _nextPhoto
                            : null,
                      ),
                    ),
                  ],
                ),

              // Penghitung foto (1/5), kiri atas.
              if (photos.length > 1)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_currentPhoto + 1}/${photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),

              // Stempel LIKE / PASS saat user memilih.
              _buildStamp(),

              // Menu report / block, kanan atas.
              Positioned(
                top: 8,
                right: 8,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: 'Opsi',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'report') _report();
                      if (value == 'block') _block();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('Laporkan')),
                      PopupMenuItem(value: 'block', child: Text('Blokir')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final profile = widget.profile;
    final bio = (profile.bio ?? '').trim();

    final locationParts = <String>[
      if ((profile.city ?? '').trim().isNotEmpty) profile.city!.trim(),
      if (profile.distanceLabel.isNotEmpty) profile.distanceLabel,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  profile.age == null
                      ? profile.name
                      : '${profile.name}, ${profile.age}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              if (profile.isFaceVerified) ...[
                const SizedBox(width: 8),
                const VerifiedBadge(size: 22),
              ],
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.45,
              ),
            ),
          ],
          if (locationParts.isNotEmpty || profile.interests.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.borderSoft),
            const SizedBox(height: 16),
          ],
          if (locationParts.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.matchaDeep,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    locationParts.join(' • '),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (profile.interests.isNotEmpty) ...[
            if (locationParts.isNotEmpty) const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests
                  .map((interest) => _InterestChip(label: interest))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _networkPhoto(String url) {
    if (url.trim().isEmpty || !url.startsWith('http')) {
      return _placeholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const CupertinoActivityIndicator(
            radius: 12,
            color: AppColors.matchaDeep,
          ),
        );
      },
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.matchaSoft.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 48,
          color: AppColors.matchaDeep,
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String label;

  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.matchaSoft.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryBorder.withValues(alpha: 0.65),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.matchaDeep,
          fontSize: 12.5,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: AppColors.ink.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: 66,
              height: 66,
              child: Icon(icon, color: iconColor, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}