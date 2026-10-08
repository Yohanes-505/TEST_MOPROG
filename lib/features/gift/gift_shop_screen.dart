import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/gift_service.dart';

class GiftShopScreen extends StatefulWidget {
  const GiftShopScreen({super.key});

  @override
  State<GiftShopScreen> createState() => _GiftShopScreenState();
}

class _GiftShopScreenState extends State<GiftShopScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GiftService _giftService = GiftService();

  List<dynamic> _gifts = [];
  int _userBalance = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Sesi pengguna tidak ditemukan.');
      }

      final userId = user.id;

      // Ambil saldo user dari tabel wallets
      final walletRes = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', userId)
          .maybeSingle();

      final balance = walletRes != null && walletRes['balance'] != null
          ? num.tryParse(walletRes['balance'].toString())?.toInt() ?? 0
          : 0;

      // Ambil katalog gift
      final giftsRes = await _supabase.from('gifts').select('*');

      if (!mounted) return;

      setState(() {
        _userBalance = balance;
        _gifts = giftsRes;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _buyGift(String giftId, dynamic priceDynamic) async {
    final price = num.tryParse(priceDynamic.toString())?.toInt() ?? 0;

    // Cek saldo terlebih dahulu
    if (_userBalance < price) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saldo utama tidak cukup!')));
      return;
    }

    // Pastikan user masih login
    final user = _supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi pengguna tidak ditemukan.')),
      );
      return;
    }

    final result = await _giftService.sendGiftToUser(giftId, user.id);

    // User mungkin sudah keluar dari halaman selama proses async
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Proses selesai.'),
      ),
    );

    // Refresh saldo dan katalog setelah pembelian berhasil
    if (result['success'] == true) {
      await _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift Shop'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Saldo: Rp $_userBalance',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          size: 48,
                          color: Colors.pinkAccent,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          gift['name']?.toString() ?? 'Gift',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text('Harga: Rp ${gift['price']}'),

                        Text(
                          'Nilai Tukar: Rp ${gift['convert_value']}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),

                        const Spacer(),

                        ElevatedButton(
                          onPressed: () =>
                              _buyGift(gift['id'].toString(), gift['price']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                          ),
                          child: const Text(
                            'Beli',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
