import 'dart:async';

import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/subscription_tier.dart';
import '../services/subscription_service.dart';
import 'likes_screen.dart';
import 'topup_screen.dart';
import 'transaction_history_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  String _selectedTierId = 'premium';

  bool _isProcessing = false;
  bool _isLoadingStatus = true;

  Map<String, dynamic>? _activeSubscription;

  int _walletBalance = 0;

  Timer? _refundWindowTimer;

  @override
  void initState() {
    super.initState();

    _loadCurrentSubscription();
    _loadWalletBalance();
  }

  @override
  void dispose() {
    _refundWindowTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentSubscription() async {
    setState(() {
      _isLoadingStatus = true;
    });

    try {
      final sub = await _subscriptionService.getMySubscription();

      final isStillActive =
          sub != null &&
          (sub['status'] == 'active' || sub['status'] == 'cancelled') &&
          sub['expires_at'] != null &&
          DateTime.parse(sub['expires_at']).isAfter(DateTime.now());

      if (!mounted) return;

      setState(() {
        _activeSubscription = isStillActive ? sub : null;

        if (isStillActive) {
          _selectedTierId = sub['tier'];
        }
      });

      _refundWindowTimer?.cancel();

      final isWithinGraceWindow =
          isStillActive &&
          sub['status'] == 'active' &&
          DateTime.now().difference(DateTime.parse(sub['started_at'])) <
              const Duration(minutes: 15);

      if (isWithinGraceWindow) {
        _refundWindowTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          final elapsed = DateTime.now().difference(
            DateTime.parse(sub['started_at']),
          );

          if (elapsed >= const Duration(minutes: 15)) {
            timer.cancel();
          }

          // Cukup rebuild.
          // Countdown dihitung ulang di build().
          setState(() {});
        });
      }
    } catch (_) {
      // Error status subscription tidak dibuat fatal
      // agar halaman tetap dapat digunakan.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _loadWalletBalance() async {
    try {
      final balance = await _subscriptionService.getWalletBalance();

      if (!mounted) return;

      setState(() {
        _walletBalance = balance;
      });
    } catch (_) {
      // Error wallet tidak dibuat fatal.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveSub = _activeSubscription != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Pilih Paket',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
        ),
        actions: [
          GestureDetector(
            onTap: () async {
              final topUpDone = await Get.to<bool>(() => const TopUpScreen());

              if (topUpDone == true) {
                _loadWalletBalance();
              }
            },
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 14,
                      color: AppColors.primaryDeep,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rp ${_formatRupiah(_walletBalance)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Menyukaimu',
            onPressed: () {
              Get.to(() => const LikesScreen());
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Riwayat Transaksi',
            onPressed: () {
              Get.to(() => const TransactionHistoryScreen());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoadingStatus)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(
                  color: AppColors.primaryDeep,
                  minHeight: 2,
                ),
              ),

            if (hasActiveSub) _buildActiveSubscriptionBanner(),

            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Upgrade untuk pengalaman matching yang lebih maksimal',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: SubscriptionTier.all.length,
                itemBuilder: (context, index) {
                  final tier = SubscriptionTier.all[index];

                  final isSelected = tier.id == _selectedTierId;

                  final isFree = tier.priceMonthly == 0;

                  final isCurrentActiveTier =
                      hasActiveSub && _activeSubscription!['tier'] == tier.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: isFree
                          ? null
                          : () {
                              setState(() {
                                _selectedTierId = tier.id;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isFree ? Colors.grey.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryDeep
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  tier.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                if (isCurrentActiveTier) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'AKTIF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ] else if (tier.isPopular) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.ink,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'POPULER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.lime,
                                      ),
                                    ),
                                  ),
                                ],

                                const Spacer(),

                                Icon(
                                  isFree
                                      ? Icons.check_circle
                                      : isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: isFree
                                      ? Colors.grey
                                      : isSelected
                                      ? AppColors.primaryDeep
                                      : Colors.grey,
                                  size: 22,
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Text(
                              tier.formattedPrice,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isFree
                                    ? Colors.grey
                                    : AppColors.textPrimary,
                              ),
                            ),

                            const SizedBox(height: 12),

                            ...tier.features.map(
                              (feature) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: AppColors.primaryDeep,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        feature,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed:
                      (_selectedTierId == 'free' ||
                          _isProcessing ||
                          (hasActiveSub &&
                              _activeSubscription!['tier'] == _selectedTierId))
                      ? null
                      : _onSubscribePressed,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _buttonLabel(hasActiveSub),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buttonLabel(bool hasActiveSub) {
    if (_selectedTierId == 'free') {
      return 'Pilih Premium atau VIP';
    }

    if (hasActiveSub && _activeSubscription!['tier'] == _selectedTierId) {
      return 'Paket Ini Sudah Aktif';
    }

    return 'Beli dengan Saldo';
  }

  Widget _buildActiveSubscriptionBanner() {
    final tier = _activeSubscription!['tier'] as String;

    final expiresAt = DateTime.parse(_activeSubscription!['expires_at']);

    final startedAt = DateTime.parse(_activeSubscription!['started_at']);

    final tierName = SubscriptionTier.all
        .firstWhere((item) => item.id == tier)
        .name;

    final formattedDate =
        '${expiresAt.day}/${expiresAt.month}/${expiresAt.year}';

    final isCancelled = _activeSubscription!['status'] == 'cancelled';

    final elapsed = DateTime.now().difference(startedAt);

    final isWithinGraceWindow =
        !isCancelled && elapsed < const Duration(minutes: 15);

    final remaining = const Duration(minutes: 15) - elapsed;

    final remainingMinutes = remaining.inMinutes.clamp(0, 15);

    final remainingSeconds = (remaining.inSeconds % 60).clamp(0, 59);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: AppColors.primaryDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kamu berlangganan $tierName, aktif sampai $formattedDate',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          if (isWithinGraceWindow) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Batal sekarang = refund 80%. Sisa waktu: ${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!isCancelled) ...[
            const SizedBox(height: 8),
            const Text(
              'Sudah lewat 15 menit — batal sekarang tidak akan ada refund.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],

          if (!isCancelled) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Perpanjangan Otomatis',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: _activeSubscription!['auto_renew'] as bool? ?? true,
                  activeThumbColor: AppColors.primaryDeep,
                  onChanged: _isProcessing ? null : _onAutoRenewToggled,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isProcessing ? null : _onCancelPressed,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text(
                  'Batalkan Langganan',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Langganan dibatalkan, akan berhenti otomatis setelah tanggal di atas.',
                style: TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onAutoRenewToggled(bool value) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _subscriptionService.setAutoRenew(value);

      await _loadCurrentSubscription();

      Get.snackbar(
        'Berhasil',
        value ? 'Perpanjangan otomatis diaktifkan.' : 'Perpanjangan otomatis dimatikan. Subscription tetap aktif sampai masa berlaku habis.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Tidak bisa mengubah pengaturan: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.errorSoft,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _onCancelPressed() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Batalkan Langganan?'),
        content: const Text(
          'Batalkan dalam 15 menit pertama sejak pembelian: dana kembali 80% ke saldo, tapi subscription langsung nonaktif saat itu juga. '
          'Batalkan setelah 15 menit: dana tidak kembali, tapi kamu tetap bisa pakai fitur premium sampai masa aktif berakhir (tidak lanjut ke bulan berikutnya).',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(result: false);
            },
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Get.back(result: true);
            },
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final refundAmount = await _subscriptionService.cancelSubscription();

      await _loadCurrentSubscription();
      await _loadWalletBalance();

      Get.snackbar(
        'Berhasil',
        refundAmount > 0
            ? 'Langganan dibatalkan & langsung nonaktif. Rp ${_formatRupiah(refundAmount)} saldo (80%) ditambahkan ke akun kamu.'
            : 'Langganan dibatalkan. Tidak ada dana kembali, tapi kamu masih bisa pakai fiturnya sampai masa aktif berakhir.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.successSoft,
      );
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Tidak bisa membatalkan langganan: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.errorSoft,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _onSubscribePressed() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _subscriptionService.purchaseWithWallet(
        _selectedTierId,
      );

      if (result.success) {
        await _loadCurrentSubscription();
        await _loadWalletBalance();

        Get.snackbar(
          'Berhasil!',
          'Paket ${result.tier} sekarang aktif.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.successSoft,
        );
      } else {
        final shortfall = (result.required ?? 0) - (result.currentBalance ?? 0);

        final wantsTopUp = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Saldo Tidak Cukup'),
            content: Text(
              'Saldo kamu Rp ${_formatRupiah(result.currentBalance ?? 0)}, dibutuhkan Rp ${_formatRupiah(result.required ?? 0)}. '
              'Kurang Rp ${_formatRupiah(shortfall)}. Mau top up sekarang?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(result: false);
                },
                child: const Text('Nanti'),
              ),
              TextButton(
                onPressed: () {
                  Get.back(result: true);
                },
                child: const Text('Top Up'),
              ),
            ],
          ),
        );

        if (wantsTopUp == true) {
          final topUpDone = await Get.to<bool>(() => const TopUpScreen());

          if (topUpDone == true) {
            await _loadWalletBalance();
          }
        }
      }
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.errorSoft,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}
