import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/models/report_model.dart';
import 'package:Meetcha/widgets/block_confirm_dialog.dart';
import 'package:Meetcha/widgets/report_bottom_sheet.dart';
import 'package:Meetcha/widgets/verified_badge.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProfileCardWidget extends StatefulWidget {
  final ProfileModel profile;

  final VoidCallback onLike;
  final VoidCallback onPass;

  final bool isFullCard;
  final bool actionsEnabled;

  /// Menampilkan menu report dan block.
  final bool showSafetyMenu;

  /// Dipanggil setelah block berhasil.
  final VoidCallback? onBlocked;

  const ProfileCardWidget({
    super.key,
    required this.profile,
    required this.onLike,
    required this.onPass,
    this.isFullCard = true,
    this.actionsEnabled = true,
    this.showSafetyMenu = true,
    this.onBlocked,
  });

  @override
  State<ProfileCardWidget> createState() => _ProfileCardWidgetState();
}

class _ProfileCardWidgetState extends State<ProfileCardWidget> {
  final PageController _photoController = PageController();

  int _currentPhoto = 0;

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  void _reportProfile() {
    showReportBottomSheet(
      context: context,
      reportedUserId: widget.profile.id,
      source: ReportSource.profile,
    );
  }

  Future<void> _blockProfile() async {
    final blocked = await showBlockConfirmDialog(
      context: context,
      blockedUserId: widget.profile.id,
      blockedUserName: widget.profile.name,
    );

    if (blocked == true) {
      widget.onBlocked?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Container(
      margin: widget.isFullCard
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.055),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isFullCard)
            Expanded(child: _buildPhotoArea())
          else
            _buildPhotoArea(fixedHeight: 310),
          _buildProfileInformation(profile),
        ],
      ),
    );
  }

  Widget _buildPhotoArea({double? fixedHeight}) {
    final photos = widget.profile.photoUrls;

    return SizedBox(
      height: fixedHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            _buildPlaceholder()
          else if (photos.length == 1)
            _buildNetworkPhoto(photos.first)
          else
            PageView.builder(
              controller: _photoController,
              physics: const BouncingScrollPhysics(),
              itemCount: photos.length,
              onPageChanged: (index) {
                if (_currentPhoto == index) {
                  return;
                }

                setState(() {
                  _currentPhoto = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildNetworkPhoto(photos[index]);
              },
            ),

          // Gradient kecil supaya navigation
          // foto dan safety button tetap terbaca.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 100,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.27),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (photos.length > 1)
            Positioned(
              top: 13,
              left: 14,
              right: widget.showSafetyMenu ? 60 : 14,
              child: _buildPhotoProgress(photos.length),
            ),

          if (widget.showSafetyMenu)
            Positioned(
              top: 14,
              right: 14,
              child: _SafetyButton(
                onReport: _reportProfile,
                onBlock: _blockProfile,
              ),
            ),

          if (photos.length > 1)
            Positioned.fill(
              top: 36,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _currentPhoto > 0 ? _goToPreviousPhoto : null,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _currentPhoto < photos.length - 1
                          ? _goToNextPhoto
                          : null,
                    ),
                  ),
                ],
              ),
            ),

          if (photos.length > 1)
            Positioned(
              right: 14,
              bottom: 14,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.92,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey(_currentPhoto),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_currentPhoto + 1}/${photos.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoProgress(int count) {
    return Row(
      children: List.generate(count, (index) {
        final selected = index == _currentPhoto;

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 3,
            margin: EdgeInsets.only(right: index == count - 1 ? 0 : 5),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 3,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProfileInformation(ProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _profileTitle(profile),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.55,
                        ),
                      ),
                    ),
                    if (profile.isFaceVerified) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(size: 19),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (_hasLocation(profile)) ...[
            const SizedBox(height: 8),
            _buildLocation(profile),
          ],

          if (_hasBio(profile)) ...[
            const SizedBox(height: 11),
            Text(
              profile.bio!.trim(),
              maxLines: widget.isFullCard ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],

          if (profile.interests.isNotEmpty) ...[
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: profile.interests
                  .take(4)
                  .map((interest) => _InterestChip(label: interest))
                  .toList(),
            ),
          ],

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _ProfileActionButton(
                  icon: Icons.close_rounded,
                  label: 'Pass',
                  foregroundColor: AppColors.textSecondary,
                  backgroundColor: AppColors.surfaceMuted,
                  borderColor: AppColors.border,
                  enabled: widget.actionsEnabled,
                  onTap: widget.onPass,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProfileActionButton(
                  icon: Icons.favorite_rounded,
                  label: 'Like',
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.matchaDeep,
                  borderColor: AppColors.matchaDeep,
                  enabled: widget.actionsEnabled,
                  onTap: widget.onLike,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocation(ProfileModel profile) {
    final locationParts = <String>[];

    if (profile.city != null && profile.city!.trim().isNotEmpty) {
      locationParts.add(profile.city!.trim());
    }

    if (profile.distanceLabel.isNotEmpty) {
      locationParts.add(profile.distanceLabel);
    }

    return Row(
      children: [
        Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: AppColors.matchaSoft.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: AppColors.matchaDeep,
            size: 15,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            locationParts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  bool _hasLocation(ProfileModel profile) {
    return (profile.city != null && profile.city!.trim().isNotEmpty) ||
        profile.distanceLabel.isNotEmpty;
  }

  bool _hasBio(ProfileModel profile) {
    return profile.bio != null && profile.bio!.trim().isNotEmpty;
  }

  String _profileTitle(ProfileModel profile) {
    if (profile.age == null) {
      return profile.name;
    }

    return '${profile.name}, ${profile.age}';
  }

  void _goToPreviousPhoto() {
    _photoController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToNextPhoto() {
    _photoController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildNetworkPhoto(String url) {
    final validPhoto = url.trim().isNotEmpty && url.startsWith('http');

    if (!validPhoto) {
      return _buildPlaceholder();
    }

    return Container(
      color: AppColors.surfaceMuted,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return Container(
            color: AppColors.surfaceMuted,
            alignment: Alignment.center,
            child: const CupertinoActivityIndicator(
              radius: 12,
              color: AppColors.matchaDeep,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.matchaSoft.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 44,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
          fontSize: 11.5,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProfileActionButton extends StatefulWidget {
  final IconData icon;
  final String label;

  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  final bool enabled;
  final VoidCallback onTap;

  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ProfileActionButton> createState() => _ProfileActionButtonState();
}

class _ProfileActionButtonState extends State<_ProfileActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.enabled ? 1.0 : 0.42;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 160),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: widget.borderColor),
              boxShadow: widget.label == 'Like'
                  ? [
                      BoxShadow(
                        color: AppColors.matchaDeep.withValues(alpha: 0.16),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: widget.foregroundColor),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.foregroundColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
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

class _SafetyButton extends StatefulWidget {
  final VoidCallback onReport;

  final Future<void> Function() onBlock;

  const _SafetyButton({required this.onReport, required this.onBlock});

  @override
  State<_SafetyButton> createState() => _SafetyButtonState();
}

class _SafetyButtonState extends State<_SafetyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 90),
      child: PopupMenuButton<String>(
        tooltip: 'Keamanan',
        offset: const Offset(0, 44),
        elevation: 8,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onOpened: () {
          setState(() {
            _pressed = true;
          });
        },
        onCanceled: () {
          setState(() {
            _pressed = false;
          });
        },
        onSelected: (value) {
          setState(() {
            _pressed = false;
          });

          if (value == 'report') {
            widget.onReport();
          }

          if (value == 'block') {
            widget.onBlock();
          }
        },
        itemBuilder: (context) {
          return const [
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: AppColors.error, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Laporkan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block_rounded, color: AppColors.error, size: 20),
                  SizedBox(width: 10),
                  Text('Blokir', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ];
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            size: 21,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
