import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/constants/interest_options.dart';
import 'package:Meetcha/controllers/profile_controller.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/services/profile_service.dart';
import 'package:Meetcha/widgets/interest_selector.dart';
import 'package:Meetcha/widgets/photo_grid_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Node flowchart: "Edit Profil & Foto".
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileController controller = ProfileController.to;

  late final TextEditingController nameController;
  late final TextEditingController ageController;
  late final TextEditingController bioController;

  Gender? _gender;
  List<String> _interests = [];

  @override
  void initState() {
    super.initState();
    final p = controller.me;
    nameController = TextEditingController(text: p?.name ?? '');
    ageController = TextEditingController(text: p?.age?.toString() ?? '');
    bioController = TextEditingController(text: p?.bio ?? '');
    _gender = p?.gender;
    _interests = List<String>.from(p?.interests ?? const []);
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      return _warn('Nama tidak boleh kosong.');
    }

    final age = int.tryParse(ageController.text.trim());
    if (age == null) return _warn('Masukkan umur yang valid.');
    if (age < 18) return _warn('Umur minimal 18 tahun.');
    if (age > 100) return _warn('Umur tidak valid.');
    if (_gender == null) return _warn('Pilih gender kamu.');
    if (_interests.length < InterestOptions.minSelected) {
      return _warn('Pilih minimal ${InterestOptions.minSelected} minat.');
    }

    final ok = await controller.saveProfile(
      name: name,
      age: age,
      bio: bioController.text.trim(),
      gender: _gender,
      interests: _interests,
    );

    if (!ok) return;

    Get.back();
    Get.snackbar('Tersimpan', 'Profil kamu berhasil diperbarui.',
        snackPosition: SnackPosition.BOTTOM);
  }

  void _warn(String message) {
    Get.snackbar('Belum bisa disimpan', message,
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil & Foto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Implementasi PhotoGridPicker yang baru
            Obx(() {
              final p = controller.me;
              if (p == null) return const SizedBox(); 
              
              return PhotoGridPicker(
                userId: p.id,
                initialPhotos: p.photoUrls,
                profileService: const ProfileService(),
              );
            }),
            const SizedBox(height: 28),
            _label('Nama'),
            TextField(
              controller: nameController,
              decoration: _decoration('Nama kamu', Icons.person_outline),
            ),
            const SizedBox(height: 20),
            _label('Umur'),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Umur kamu', Icons.cake_outlined),
            ),
            const SizedBox(height: 20),
            _label('Gender'),
            Wrap(
              spacing: 10,
              children: Gender.values.map((g) {
                final selected = _gender == g;
                return ChoiceChip(
                  label: Text(g.label),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _gender = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _label('Bio'),
            TextField(
              controller: bioController,
              maxLines: 4,
              maxLength: 300,
              decoration: _decoration('Ceritakan tentang kamu', null),
            ),
            const SizedBox(height: 12),
            _label('Minat & Hobi'),
            InterestSelector(
              selected: _interests,
              onChanged: (next) => setState(() => _interests = next),
            ),
            const SizedBox(height: 28),
            _locationRow(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Obx(() => ElevatedButton(
                    onPressed: controller.isSaving.value ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isSaving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text(
                            'Simpan Perubahan',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  )),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _locationRow() {
    return Obx(() {
      final p = controller.me;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.location_on_outlined),
        title: const Text('Lokasi'),
        subtitle: Text(
          p?.hasLocation == true
              ? (p?.city ?? 'Tersimpan')
              : 'Belum diatur',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: controller.isLocating.value
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () => controller.refreshLocation(),
                child: const Text('Perbarui'),
              ),
      );
    });
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  InputDecoration _decoration(String hint, IconData? icon) => InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}