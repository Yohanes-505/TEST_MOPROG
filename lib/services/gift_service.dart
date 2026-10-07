import 'package:supabase_flutter/supabase_flutter.dart';

class GiftService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fungsi Beli Gift via RPC
  Future<Map<String, dynamic>> buyGift(String giftId) async {
    try {
      final response = await _supabase.rpc(
        'buy_gift',
        params: {'p_gift_id': giftId},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Konversi Gift via RPC
  Future<Map<String, dynamic>> convertGift(String userGiftId) async {
    try {
      final response = await _supabase.rpc(
        'convert_gift',
        params: {'p_user_gift_id': userGiftId},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}