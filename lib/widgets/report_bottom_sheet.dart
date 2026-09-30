import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bumble/models/report_model.dart';
import 'package:bumble/services/report_service.dart';

const List<String> _reportReasons = [
  'Spam atau penipuan',
  'Konten tidak pantas',
  'Perilaku kasar',
  'Akun palsu',
  'Lainnya',
];

Future<void> showReportBottomSheet({
  required BuildContext context,
  required String reportedUserId,
  required ReportSource source,
  String? chatRoomId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => ReportBottomSheet(
      reportedUserId: reportedUserId,
      source: source,
      chatRoomId: chatRoomId,
    ),
  );
}

class ReportBottomSheet extends StatefulWidget {
  final String reportedUserId;
  final ReportSource source;
  final String? chatRoomId;

  const ReportBottomSheet({
    super.key,
    required this.reportedUserId,
    required this.source,
    this.chatRoomId,
  });

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  String? _selectedReason;
  final _otherReasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reporterId = Supabase.instance.client.auth.currentUser?.id;

    if (reporterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi berakhir, silakan login ulang')),
      );
      return;
    }

    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih alasan report dulu ya')),
      );
      return;
    }

    final reason = _selectedReason == 'Lainnya'
        ? _otherReasonController.text.trim()
        : _selectedReason!;

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis dulu alasannya')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ReportService.submitReport(
      reporterId: reporterId,
      reportedUserId: widget.reportedUserId,
      reason: reason,
      source: widget.source,
      chatRoomId: widget.chatRoomId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan kamu sudah dikirim, tim kami akan meninjau'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim laporan, coba lagi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laporkan Pengguna',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih alasan kamu melaporkan pengguna ini',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ..._reportReasons.map(
            (reason) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) => setState(() => _selectedReason = value),
            ),
          ),
          if (_selectedReason == 'Lainnya')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _otherReasonController,
                decoration: const InputDecoration(
                  hintText: 'Tulis alasan kamu...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kirim Laporan'),
            ),
          ),
        ],
      ),
    );
  }
}
