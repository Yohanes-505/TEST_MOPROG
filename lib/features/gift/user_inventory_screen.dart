import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gift_service.dart';

class UserInventoryScreen extends StatefulWidget {
  const UserInventoryScreen({Key? key}) : super(key: key);

  @override
  State<UserInventoryScreen> createState() => _UserInventoryScreenState();
}

class _UserInventoryScreenState extends State<UserInventoryScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GiftService _giftService = GiftService();
  
  List<dynamic> _myGifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Ambil data gift milik user yang statusnya masih 'active' beserta relasi ke tabel gifts
      final response = await _supabase
          .from('user_gifts')
          .select('id, status, gifts(name, price, convert_value)')
          .eq('user_id', userId)
          .eq('status', 'active');

      setState(() {
        _myGifts = response;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat inventori: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _convertGift(String userGiftId, int convertValue) async {
    // Tampilkan konfirmasi sebelum konversi
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konversi Gift'),
        content: Text('Yakin ingin mengonversi gift ini menjadi saldo sebesar Rp $convertValue? (Nilai lebih rendah dari harga beli)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Konversi')),
        ],
      ),
    );

    if (confirm != true) return;

    // Panggil fungsi RPC convert_gift
    final result = await _giftService.convertGift(userGiftId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'])),
    );

    if (result['success'] == true) {
      _fetchInventory(); // Refresh list inventori
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gift Saya & Konversi Saldo')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myGifts.isEmpty
              ? const Center(child: Text('Belum ada gift di inventori.'))
              : ListView.builder(
                  itemCount: _myGifts.length,
                  itemBuilder: (context, index) {
                    final item = _myGifts[index];
                    final giftDetail = item['gifts'];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.card_giftcard, color: Colors.orange, size: 40),
                        title: Text(giftDetail['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Nilai Konversi: Rp ${giftDetail['convert_value']}'),
                        trailing: ElevatedButton(
                          onPressed: () => _convertGift(item['id'], giftDetail['convert_value']),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Convert ke Saldo', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}