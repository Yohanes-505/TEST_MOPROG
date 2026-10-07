import 'package:supabase_flutter/supabase_flutter.dart';

class FaceVerificationService {
  FaceVerificationService._();

  static final FaceVerificationService instance =
      FaceVerificationService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  Future<bool> isVerified() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      final row = await _supabase
          .from('profiles')
          .select('is_face_verified')
          .eq('id', user.id)
          .maybeSingle();

      return (row?['is_face_verified'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}