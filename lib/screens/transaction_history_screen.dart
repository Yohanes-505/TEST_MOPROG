import 'package:Meetcha/constants/app_colors.dart';
// lib/screens/subscription/transaction_history_screen.dart
//
// Fix: sejak Hari 8, tabel transactions cuma untuk TOP UP (kolom tier
// bisa null). Card sekarang menampilkan "Top Up Saldo" kalau tier null.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/subscription_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final SubscriptionService _service = SubscriptionService();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getTransactionHistory();
      setState(() => _transactions = data);
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Tidak bisa memuat riwayat transaksi: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryDeep,
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryDeep))
            : _transactions.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text('Belum ada riwayat transaksi', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: _transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildTransactionCard(_transactions[index]),
                  ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> trx) {
    // tier bisa null (transaksi top up sejak Hari 8), tampilkan label
    // yang sesuai.
    final tierRaw = trx['tier'] as String?;
    final title = tierRaw != null ? 'Subscription ${tierRaw.toUpperCase()}' : 'Top Up Saldo';

    final amount = trx['amount'] as int;
    final status = trx['payment_status'] as String;
    final createdAt = DateTime.parse(trx['created_at']);
    final formattedDate =
        "${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";
    final formattedAmount = amount.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]}.',
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(formattedDate, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('Rp $formattedAmount', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _buildStatusBadge(status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    late Color color;
    late String label;

    switch (status) {
      case 'settlement':
        color = AppColors.success;
        label = 'Berhasil';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Menunggu';
        break;
      case 'expire':
        color = AppColors.textSecondary;
        label = 'Kedaluwarsa';
        break;
      case 'cancel':
      case 'deny':
        color = AppColors.error;
        label = 'Gagal';
        break;
      default:
        color = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}