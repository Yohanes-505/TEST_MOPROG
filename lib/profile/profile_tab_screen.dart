import 'package:bumble/authentication/welcome_screen.dart';
import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/profile/blocked_users_screen.dart';
import 'package:bumble/profile/edit_profile_screen.dart';
import 'package:bumble/profile/filter_preference_screen.dart';
import 'package:bumble/profile/safe_dating_tips_screen.dart';
import 'package:bumble/screens/subscription_screen.dart';
import 'package:bumble/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Node flowchart: "Tab: Profile".
/// Berisi ringkasan profil + pintu masuk ke Edit Profil & Foto,
/// Filter Preferensi, Subscription, dan Safe Dating Tips.
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ProfileController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: controller.loadProfile,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.me == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = controller.me;
        if (profile == null) {
          return const Center(child: Text('Profil tidak ditemukan.'));
        }

        return RefreshIndicator(
          onRefresh: controller.loadProfile,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _headerCard(profile, controller),
              const SizedBox(height: 20),
              _completenessCard(profile),
              const SizedBox(height: 20),
              _sectionTitle('Akun'),
              _menuTile(
                icon: Icons.edit_outlined,
                title: 'Edit Profil & Foto',
                subtitle: 'Ubah foto, bio, dan minat kamu',
                onTap: () => Get.to(() => const EditProfileScreen()),
              ),
              _menuTile(
                icon: Icons.tune,
                title: 'Filter Preferensi',
                subtitle:
                    '${profile.prefMinAge}-${profile.prefMaxAge} th • '
                    '${profile.prefMaxDistanceKm} km',
                onTap: () => Get.to(() => const FilterPreferenceScreen()),
              ),
              _menuTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Subscription',
                subtitle: 'Free / Premium / VIP',
                onTap: () => Get.to(() => const SubscriptionScreen()),
              ),
              const SizedBox(height: 12),
              _sectionTitle('Keamanan'),
              _menuTile(
                icon: Icons.health_and_safety_outlined,
                title: 'Safe Dating Tips',
                subtitle: 'Panduan aman sebelum bertemu orang baru',
                onTap: () => Get.to(() => const SafeDatingTipsScreen()),
              ),
              _menuTile(
                icon: Icons.block,
                title: 'Akun yang Diblokir',
                subtitle: 'Lihat & buka blokir akun yang pernah kamu blokir',
                onTap: () => Get.to(() => const BlockedUsersScreen()),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Keluar',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      }),
    );
  }

  Widget _headerCard(ProfileModel profile, ProfileController controller) {
    return Column(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
              (profile.photoUrl != null && profile.photoUrl!.startsWith('http'))
                  ? NetworkImage(profile.photoUrl!)
                  : null,
          child: (profile.photoUrl == null ||
                  !profile.photoUrl!.startsWith('http'))
              ? Icon(Icons.person, size: 48, color: Colors.grey.shade500)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          profile.age == null
              ? profile.name
              : '${profile.name}, ${profile.age}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (profile.gender != null)
          Text(
            profile.gender!.label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => controller.refreshLocation(),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => controller.isLocating.value
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        profile.hasLocation
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        size: 16,
                        color: profile.hasLocation
                            ? AppColors.primaryDeep
                            : AppColors.textSecondary,
                      )),
                const SizedBox(width: 6),
                Text(
                  profile.hasLocation
                      ? (profile.city ?? 'Lokasi aktif')
                      : 'Aktifkan lokasi',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if ((profile.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            profile.bio!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        if (profile.interests.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: profile.interests
                .map<Widget>((i) => Chip(
                      label: Text(i, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _completenessCard(ProfileModel profile) {
    final percent = (profile.completeness * 100).round();
    if (percent >= 100) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kelengkapan profil: $percent%',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: profile.completeness,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Profil yang lengkap punya peluang match lebih besar.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: Icon(icon, color: AppColors.ink, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu login lagi untuk masuk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await supabase.auth.signOut();
    Get.delete<ProfileController>(force: true);
    Get.offAll(() => const WelcomeScreen());
  }
}