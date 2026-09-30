import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/services/swipe_service.dart';
import 'package:bumble/widgets/match_dialog.dart';
import 'package:bumble/widgets/profile_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/subscription_service.dart';
import 'subscription_screen.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  final SubscriptionService _service = SubscriptionService();
  final SwipeService _swipeService = const SwipeService();

  LikersResult? _result;

  List<ProfileModel> _likers = [];

  final Set<String> _busyIds = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load(showSpinner: false); 
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final result = await _service.getMyLikers();
      final likers = result.eligible
          ? await _swipeService.getPendingLikerProfiles(result.likerIds)
          : <ProfileModel>[];

      if (!mounted) return;
      setState(() {
        _result = result;
        _likers = likers;
      });
    } catch (e) {
      Get.snackbar('Gagal', 'Tidak bisa memuat data: ${e.toString()}', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kalau di-like balik, langsung jadi match.
  Future<void> _respond(ProfileModel profile, SwipeAction action) async {
    if (_busyIds.contains(profile.id)) return;
    setState(() => _busyIds.add(profile.id));

    try {
      final isMatch = await _swipeService.submit(
        targetId: profile.id,
        action: action,
      );
      if (!mounted) return;

      setState(() => _likers.removeWhere((p) => p.id == profile.id));

      if (isMatch) await showMatchDialog(profile);
    } catch (e) {
      Get.snackbar('Gagal', 'Pilihanmu belum tersimpan. Coba lagi.', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _busyIds.remove(profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        leading: IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Menyukaimu', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDeep))
          : (_result == null
              ? const SizedBox()
              : (_result!.eligible ? _buildEligibleView() : _buildUpsellView())),
    );
  }

  Widget _buildEligibleView() {
    if (_likers.isEmpty) {
      final hasRespondedAll = _result!.likerIds.isNotEmpty;
      return RefreshIndicator(
        color: AppColors.primaryDeep,
        onRefresh: () => _load(showSpinner: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            const Icon(Icons.favorite_border, size: 48, color: AppColors.mist),
            const SizedBox(height: 12),
            Center(
              child: Text(
                hasRespondedAll
                    ? 'Kamu sudah merespons semua yang menyukaimu'
                    : 'Belum ada yang like kamu',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryDeep,
      onRefresh: () => _load(showSpinner: false),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _likers.length,
        itemBuilder: (context, index) {
          final profile = _likers[index];
          return ProfileCardWidget(
            profile: profile,
            isFullCard: false,
            actionsEnabled: !_busyIds.contains(profile.id),
            onLike: () => _respond(profile, SwipeAction.like),
            onPass: () => _respond(profile, SwipeAction.dislike),
          );
        },
      ),
    );
  }

  Widget _buildUpsellView() {
    final count = _result!.totalCount;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(3, (i) {
                return Positioned(
                  top: i * 10.0,
                  child: Transform.rotate(
                    angle: (i - 1) * 0.08,
                    child: Container(
                      width: 140,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.favorite, color: Colors.white, size: 40),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            count > 0 ? '$count orang menyukaimu!' : 'Lihat siapa yang menyukaimu',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Upgrade ke Premium atau VIP untuk melihat semua orang yang sudah menyukaimu.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Get.to(() => const SubscriptionScreen()),
              child: const Text('Upgrade Sekarang', style: TextStyle(fontSize: 16, color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
