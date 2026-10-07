import 'package:shared_preferences/shared_preferences.dart';
import 'package:bumble/services/supabase_service.dart';

class SessionTimeoutService {
  // Ubah sesuai kebutuhan
  static const Duration maxInactive = Duration(days: 7);
  static const _key = 'last_active_at';

  /// Simpan waktu sekarang sebagai terakhir aktif
  static Future<void> touch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }

  /// true kalau user sudah tidak aktif terlalu lama otomatis logout
  static Future<bool> checkExpiredAndLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_key);

    if (last == null) {
      await touch();
      return false;
    }

    final lastActive = DateTime.fromMillisecondsSinceEpoch(last);
    final expired = DateTime.now().difference(lastActive) > maxInactive;

    if (expired) {
      await supabase.auth.signOut();
      await prefs.remove(_key);
    }
    return expired;
  }

  /// Hapus catatan waktu aktif (dipanggil saat logout)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}