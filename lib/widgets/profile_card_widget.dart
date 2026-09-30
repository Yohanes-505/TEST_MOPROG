import 'package:flutter/material.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/constants/app_colors.dart';

class ProfileCardWidget extends StatefulWidget {
  final ProfileModel profile;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final bool isFullCard;
  final bool actionsEnabled;

  const ProfileCardWidget({
    super.key,
    required this.profile,
    required this.onLike,
    required this.onPass,
    this.isFullCard = true,
    this.actionsEnabled = true,
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

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Container(
      margin: widget.isFullCard
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isFullCard)
            Expanded(child: _buildPhotoCarousel())
          else
            _buildPhotoCarousel(fixedHeight: 260),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${profile.name}${profile.age != null ? ', ${profile.age}' : ''}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (profile.city != null && profile.city!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            profile.city!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    profile.bio!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
                if (profile.interests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: profile.interests.take(3).map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          interest,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton(
                      icon: Icons.close,
                      label: 'Dislike',
                      color: Colors.grey.shade600,
                      onTap: actionsEnabled ? onPass : null,
                    ),
                    _actionButton(
                      icon: Icons.favorite,
                      label: 'Like',
                      color: AppColors.primaryDeep,
                      onTap: actionsEnabled ? onLike : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carousel foto. Kalau cuma ada 0-1 foto, tampil seperti gambar biasa
  /// (tidak ada PageView/dots) — supaya tidak ada overhead atau swipe
  /// kosong untuk profil yang belum upload banyak foto.
  Widget _buildPhotoCarousel({double? fixedHeight}) {
    final photos = widget.profile.photoUrls;

    if (photos.isEmpty) {
      return SizedBox(
        height: fixedHeight,
        width: double.infinity,
        child: _placeholder(),
      );
    }

    if (photos.length == 1) {
      return SizedBox(
        height: fixedHeight,
        width: double.infinity,
        child: _networkPhoto(photos.first),
      );
    }

    return SizedBox(
      height: fixedHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _photoController,
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _currentPhoto = index),
            itemBuilder: (context, index) => _networkPhoto(photos[index]),
          ),
          // Tap kiri/kanan untuk pindah foto tanpa perlu swipe penuh —
          // pola umum di dating app (mirip Instagram Stories).
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _currentPhoto > 0 ? _goToPrevPhoto : null,
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
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(photos.length, (index) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(
                      right: index == photos.length - 1 ? 0 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: index == _currentPhoto
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPrevPhoto() {
    _photoController.previousPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _goToNextPhoto() {
    _photoController.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Widget _networkPhoto(String url) {
    final hasValidPhoto = url.isNotEmpty && url.startsWith('http');
    if (!hasValidPhoto) return _placeholder();

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.person, size: 80, color: Colors.grey),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final effectiveColor = onTap == null ? Colors.grey.shade300 : color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: effectiveColor, width: 2),
            ),
            child: Icon(icon, color: effectiveColor, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
