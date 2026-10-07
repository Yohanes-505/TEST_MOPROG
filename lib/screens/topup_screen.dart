import 'package:Meetcha/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/subscription_service.dart';
import 'payment_webview_screen.dart';
import 'wallet_history_screen.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final SubscriptionService _service = SubscriptionService();

  static const List<int> _presetAmounts = [20000, 50000, 100000, 200000];

  int? _selectedAmount;
  final TextEditingController _customAmountController = TextEditingController();
  bool _isProcessing = false;
  int _walletBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final balance = await _service.getWalletBalance();
    if (mounted) setState(() => _walletBalance = balance);
  }

  int? get _effectiveAmount {
    if (_customAmountController.text.isNotEmpty) {
      return int.tryParse(_customAmountController.text.replaceAll('.', ''));
    }
    return _selectedAmount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        leading: IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.arrow_back)),
        title: const Text('Top Up Saldo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo Kamu Sekarang', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${_formatRupiah(_walletBalance)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDeep),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Get.to(() => const WalletHistoryScreen()),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Lihat Riwayat Saldo', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Pilih Nominal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetAmounts.map((amount) {
                  final isSelected = _selectedAmount == amount && _customAmountController.text.isEmpty;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedAmount = amount;
                      _customAmountController.clear();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                      ),
                      child: Text(
                        'Rp ${_formatRupiah(amount)}',
                        style: TextStyle(
                          color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text('Atau Masukkan Nominal Lain', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _customAmountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Minimal Rp 10.000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_effectiveAmount == null || _effectiveAmount! < 10000 || _isProcessing)
                      ? null
                      : _onTopUpPressed,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2),
                        )
                      : const Text('Lanjut ke Pembayaran', style: TextStyle(fontSize: 16, color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTopUpPressed() async {
    final amount = _effectiveAmount!;
    setState(() => _isProcessing = true);

    try {
      final result = await _service.createTopUp(amount);
      if (!mounted) return;

      final paymentFinished = await Get.to<bool>(
        () => PaymentWebviewScreen(redirectUrl: result.redirectUrl, orderId: result.orderId),
      );

      if (!mounted) return;
      if (paymentFinished == true) {
        await _pollForBalanceUpdate();
      }
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.errorSoft,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pollForBalanceUpdate() async {
    final balanceBefore = _walletBalance;

    Get.snackbar(
      'Memeriksa Status',
      'Menunggu konfirmasi pembayaran...',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );

    const maxAttempts = 6;
    const delay = Duration(seconds: 3);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(delay);
      if (!mounted) return;

      final newBalance = await _service.getWalletBalance();
      if (newBalance > balanceBefore) {
        setState(() => _walletBalance = newBalance);
        Get.snackbar(
          'Berhasil!',
          'Saldo bertambah Rp ${_formatRupiah(newBalance - balanceBefore)}.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.successSoft,
        );
        Get.back(result: true); // beri tahu screen sebelumnya untuk refresh saldo juga
        return;
      }
    }

    Get.snackbar(
      'Belum Terkonfirmasi',
      'Status pembayaran belum berubah. Coba cek lagi beberapa saat lagi.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.warningSoft,
    );
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}