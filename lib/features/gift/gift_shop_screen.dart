import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gift_service.dart';

class GiftShopScreen extends StatefulWidget {
  const GiftShopScreen({Key? key}) : super(key: key);

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
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Ambil saldo langsung dari tabel 'wallets'
      final walletRes = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', userId) // Kurung tutup dan titik koma sudah diperbaiki dengan benar
          .maybeSingle();
      
      if (walletRes != null && walletRes['balance'] != null) {
        _userBalance = num.tryParse(walletRes['balance'].toString())?.toInt() ?? 0;
      } else {
        _userBalance = 0;
      }

      // Ambil katalog gift
      final giftsRes = await _supabase.from('gifts').select('*');
      _gifts = giftsRes;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buyGift(String giftId, dynamic priceDynamic) async {
    // Konversi harga gift ke int secara aman
    int price = num.tryParse(priceDynamic.toString())?.toInt() ?? 0;

    if (_userBalance < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo utama tidak cukup!')),
      );
      return;
    }

    final userId = _supabase.auth.currentUser!.id;
    final result = await _giftService.sendGiftToUser(giftId, userId);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'])),
    );

    if (result['success'] == true) {
      _fetchData(); // Refresh saldo & UI setelah beli
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
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Saldo: Rp $_userBalance',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.card_giftcard, size: 48, color: Colors.pinkAccent),
                        const SizedBox(height: 8),
                        Text(
                          gift['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text('Harga: Rp ${gift['price']}'),
                        Text(
                          'Nilai Tukar: Rp ${gift['convert_value']}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => _buyGift(gift['id'], gift['price']),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                          child: const Text('Beli', style: TextStyle(color: Colors.white)),
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