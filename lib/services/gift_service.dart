import 'package:supabase_flutter/supabase_flutter.dart';

class GiftService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Membeli atau mengirim gift ke user lain (memanggil fungsi RPC Supabase)
  Future<Map<String, dynamic>> sendGiftToUser(String giftId, String receiverId) async {
    try {
      final response = await _supabase.rpc(
        'send_gift_to_user',
        params: {
          'p_gift_id': giftId,
          'p_receiver_id': receiverId,
        },
      );
      
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': true, 'message': 'Gift berhasil dikirim!'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Mengonversi Gift di inventory menjadi saldo (nilai lebih rendah)
  Future<Map<String, dynamic>> convertGift(String userGiftId) async {
    try {
      final response = await _supabase.rpc(
        'convert_gift',
        params: {'p_user_gift_id': userGiftId},
      );
      
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': true, 'message': 'Gift berhasil dikonversi ke saldo!'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}