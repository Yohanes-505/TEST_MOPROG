import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/block_service.dart';

Future<bool?> showBlockConfirmDialog({
  required BuildContext context,
  required String blockedUserId,
  required String blockedUserName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _BlockConfirmDialog(
      blockedUserId: blockedUserId,
      blockedUserName: blockedUserName,
    ),
  );
}

class _BlockConfirmDialog extends StatefulWidget {
  final String blockedUserId;
  final String blockedUserName;

  const _BlockConfirmDialog({
    required this.blockedUserId,
    required this.blockedUserName,
  });

  @override
  State<_BlockConfirmDialog> createState() => _BlockConfirmDialogState();
}

class _BlockConfirmDialogState extends State<_BlockConfirmDialog> {
  bool _isSubmitting = false;

  Future<void> _confirmBlock() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await BlockService.blockUser(
      blockerId: currentUser.id,
      blockedId: widget.blockedUserId,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.blockedUserName} sudah diblokir. Kalian tidak akan '
            'saling melihat lagi.',
          ),
        ),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memblokir, coba lagi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Blokir Pengguna?'),
      content: Text(
        'Setelah diblokir, kamu dan ${widget.blockedUserName} tidak akan '
        'saling muncul lagi di swipe maupun chat. Tindakan ini bisa '
        'dibatalkan lewat pengaturan.',
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _confirmBlock,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Blokir', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}