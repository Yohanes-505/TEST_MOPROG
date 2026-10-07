import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/services/block_service.dart';
import 'package:bumble/services/swipe_service.dart';
import 'package:bumble/widgets/match_dialog.dart';
import 'package:bumble/widgets/profile_card_widget.dart';

final _supabaseClient = Supabase.instance.client;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProfileModel> dailyBrew = [];
  bool isLoading = true;
  final int dailyLimit = 5;

  final SwipeService _swipeService = const SwipeService();

  /// id profil yang pilihannya sedang dikirim (cegah tap ganda).
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    fetchDailyBrew();
  }

  Future<void> fetchDailyBrew() async {
    setState(() => isLoading = true);
    try {
      final myId = _supabaseClient.auth.currentUser?.id;
      if (myId == null) {
        throw StateError('Sesi berakhir. Silakan login ulang.');
      }

      final swiped = await _supabaseClient
          .from('swipes')
          .select('swiped_id')
          .eq('swiper_id', myId);

      // Perbaikan tipe data untuk mencegah casting error
      final swipedIds = (swiped as List)
          .map((e) => e['swiped_id'].toString())
          .toList();

      // User yang sudah saling block gak boleh muncul lagi di swipe
      final hiddenIds = await BlockService.getHiddenUserIds(myId);

      final excludedIds = {...swipedIds, ...hiddenIds}.toList();

      var query = _supabaseClient.from('profiles').select().neq('id', myId);

      if (excludedIds.isNotEmpty) {
        query = query.not('id', 'in', excludedIds);
      }

      final result = await query.limit(dailyLimit);

      if (mounted) {
        setState(() {
          dailyBrew = (result as List)
              .map((e) => ProfileModel.fromMap(e))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Failed to load matches',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> handleSwipe(ProfileModel profile, SwipeAction action) async {
    if (_busyIds.contains(profile.id)) return;
    setState(() => _busyIds.add(profile.id));

    try {
      // Simpan pilihan; kalau Like dan orang itu sudah lebih dulu like kita,
      // match dibuat dan `isMatch` bernilai true.
      final isMatch = await _swipeService.submit(
        targetId: profile.id,
        action: action,
      );

      if (mounted) {
        setState(() {
          dailyBrew.removeWhere((p) => p.id == profile.id);
        });
      }

      if (isMatch) {
        await showMatchDialog(profile);
      } else if (action == SwipeAction.like) {
        Get.snackbar(
          'Liked',
          profile.name,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Something went wrong',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Matcha",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDailyBrew,
              child: dailyBrew.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 150),
                        Center(
                          child: Text(
                            "No more Daily Brew today \nCome back tomorrow!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Today's Daily Brew  (${dailyBrew.length} left)",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: dailyBrew.length,
                            itemBuilder: (context, index) {
                              final profile = dailyBrew[index];
                              return Container(
                                height: 450,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ProfileCardWidget(
                                  profile: profile,
                                  actionsEnabled: !_busyIds.contains(profile.id),
                                  onLike: () =>
                                      handleSwipe(profile, SwipeAction.like),
                                  onPass: () =>
                                      handleSwipe(profile, SwipeAction.dislike),
                                  onBlocked: () {
                                    if (mounted) {
                                      setState(() => dailyBrew
                                          .removeWhere((p) => p.id == profile.id));
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}