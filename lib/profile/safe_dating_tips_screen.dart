import 'package:Meetcha/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Node flowchart: "Safe Dating Tips (Konten Statis)".
/// Gratis untuk semua tier (Free, Premium, VIP).
class SafeDatingTipsScreen extends StatelessWidget {
  const SafeDatingTipsScreen({super.key});

  static const List<_Tip> _tips = [
    _Tip(
      icon: Icons.chat_bubble_outline,
      title: 'Kenalan dulu di dalam aplikasi',
      body:
          'Tetap chat di aplikasi sampai kamu benar-benar nyaman. Jangan '
          'buru-buru pindah ke WhatsApp atau media sosial pribadi.',
    ),
    _Tip(
      icon: Icons.person_off_outlined,
      title: 'Jaga data pribadi',
      body:
          'Jangan bagikan alamat rumah, alamat kantor, nomor rekening, NIK, '
          'atau kode OTP kepada siapa pun yang baru kamu kenal.',
    ),
    _Tip(
      icon: Icons.storefront_outlined,
      title: 'Bertemu di tempat ramai',
      body:
          'Untuk pertemuan pertama, pilih kafe, restoran, atau mal yang ramai '
          'dan terang. Hindari rumah pribadi atau tempat sepi.',
    ),
    _Tip(
      icon: Icons.directions_car_outlined,
      title: 'Atur transportasi sendiri',
      body:
          'Datang dan pulang dengan kendaraan sendiri atau transportasi online '
          'atas namamu, supaya kamu bisa pergi kapan pun merasa tidak nyaman.',
    ),
    _Tip(
      icon: Icons.share_outlined,
      title: 'Beri tahu orang terdekat',
      body:
          'Kabari teman atau keluarga tentang siapa yang kamu temui, di mana, '
          'dan jam berapa. Bagikan lokasi langsung jika memungkinkan.',
    ),
    _Tip(
      icon: Icons.attach_money,
      title: 'Waspadai modus penipuan',
      body:
          'Permintaan uang, ajakan investasi atau kripto, dan cerita darurat '
          'yang mendesak adalah tanda bahaya. Jangan pernah kirim uang.',
    ),
    _Tip(
      icon: Icons.favorite_border,
      title: 'Percaya insting kamu',
      body:
          'Kalau ada yang terasa janggal, kamu tidak wajib melanjutkan. '
          'Berhenti chat, keluar dari pertemuan, dan tidak perlu minta maaf.',
    ),
    _Tip(
      icon: Icons.flag_outlined,
      title: 'Laporkan dan blokir',
      body:
          'Gunakan tombol Report/Unmatch di chat atau profil untuk melaporkan '
          'perilaku kasar, pelecehan, atau akun palsu. Laporan kamu anonim.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Dating Tips')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Keamanan kamu nomor satu. Baca panduan singkat ini sebelum '
              'bertemu seseorang dari aplikasi.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 20),
          ..._tips.map((t) => _tipCard(t)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Dalam keadaan darurat di Indonesia, hubungi 112. '
            'Untuk kekerasan terhadap perempuan dan anak, hubungi SAPA 129.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tipCard(_Tip tip) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(tip.icon, color: AppColors.primaryDeep),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tip.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    tip.body,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip {
  final IconData icon;
  final String title;
  final String body;

  const _Tip({required this.icon, required this.title, required this.body});
}