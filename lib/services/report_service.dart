import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Meetcha/models/report_model.dart';

class ReportService {
  static final _supabase = Supabase.instance.client;

  static Future<bool> submitReport({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    required ReportSource source,
    String? chatRoomId,
  }) async {
    try {
      final report = ReportModel(
        reporterId: reporterId,
        reportedUserId: reportedUserId,
        reason: reason,
        source: source,
        chatRoomId: chatRoomId,
      );

      await _supabase.from('reports').insert(report.toJson());
      return true;
    } catch (e) {
      debugPrint('Gagal kirim report: $e');
      return false;
    }
  }
}