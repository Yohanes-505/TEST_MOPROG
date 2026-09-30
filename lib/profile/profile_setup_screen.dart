import 'dart:typed_data';

import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/constants/interest_options.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:bumble/home/main_shell.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/widgets/interest_selector.dart';
import 'package:bumble/widgets/photo_picker_avatar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Node flowchart: "Profile Setup — Gender, Bio, Interest/Hobby Tags,
/// Preferensi & Lokasi GPS".
///
/// Dibagi jadi 3 langkah supaya tidak satu form panjang:
///   1. Tentang kamu  : foto, umur, gender, bio
///   2. Minat         : interest/hobby tags
///   3. Lokasi        : izin GPS + filter preferensi awal
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final ProfileController controller = ProfileController.to;

  final PageController _pageController = PageController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController bioController = TextEditingController();

  int _step = 0;
  Gender? _gender;
  List<String> _interests = [];
  Uint8List? _photoPreview;

  // Filter preferensi awal
  Gender? _prefGender;
  RangeValues _ageRange = const RangeValues(18, 35);
  double _maxDistance = 50;

  static const int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    // Nama mungkin sudah terisi dari signup; kalau belum, user isi di sini.
    nameController.text = controller.me?.name ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // Validasi & navigasi antar langkah
  // ----------------------------------------------------------------

  String? _validateStepOne() {
    if (nameController.text.trim().isEmpty) return 'Isi nama kamu dulu.';
    final age = int.tryParse(ageController.text.trim());
    if (age == null) return 'Masukkan umur yang valid.';
    if (age < 18) return 'Kamu harus berusia minimal 18 tahun.';
    if (age > 100) return 'Umur tidak valid.';
    if (_gender == null) return 'Pilih gender kamu.';
    return null;
  }

  String? _validateStepTwo() {
    if (_interests.length < InterestOptions.minSelected) {
      return 'Pilih minimal ${InterestOptions.minSelected} minat.';
    }
    return null;
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onNext() async {
    final error = _step == 0 ? _validateStepOne() : _validateStepTwo();
    if (_step < 2 && error != null) {
      Get.snackbar('Belum lengkap', error,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (_step < _totalSteps - 1) {
      _goTo(_step + 1);
      return;
    }

    await _finish();
  }

  Future<void> _finish() async {
    final profile = controller.me;
    if (profile == null || !profile.hasLocation) {
      Get.snackbar(
        'Lokasi dibutuhkan',
        'Aktifkan lokasi dulu supaya kami bisa mencarikan orang di sekitarmu.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final saved = await controller.saveProfile(
      name: nameController.text.trim(),
      age: int.parse(ageController.text.trim()),
      bio: bioController.text.trim(),
      gender: _gender,
      interests: _interests,
    );
    if (!saved) return;

    await controller.savePreferences(
      prefGender: _prefGender,
      minAge: _ageRange.start.round(),
      maxAge: _ageRange.end.round(),
      maxDistanceKm: _maxDistance.round(),
    );

    Get.offAll(() => const MainShell());
  }

  Future<void> _onPhotoPicked(Uint8List bytes, String ext) async {
    setState(() => _photoPreview = bytes);
    await controller.uploadPhoto(bytes, extension: ext);
  }

  // ----------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepAboutYou(),
                  _stepInterests(),
                  _stepLocation(),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    const titles = ['Tentang Kamu', 'Minat Kamu', 'Lokasi & Preferensi'];
    const subtitles = [
      'Isi data dasar supaya orang lain kenal kamu',
      'Pilih minat agar kami cocokkan dengan orang yang mirip',
      'Kami butuh lokasi untuk mencari orang di sekitarmu',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_totalSteps, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == _totalSteps - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Text(
            titles[_step],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitles[_step],
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _stepAboutYou() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() => PhotoPickerAvatar(
                photoUrl: controller.me?.photoUrl,
                localPreview: _photoPreview,
                isUploading: controller.isSaving.value,
                onPicked: _onPhotoPicked,
              )),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Foto profil (opsional, tapi sangat disarankan)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 28),
          _label('Nama'),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration(
              hint: 'Nama yang tampil di profil kamu',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 20),
          _label('Umur'),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(
              hint: 'Masukkan umur kamu',
              icon: Icons.cake_outlined,
            ),
          ),
          const SizedBox(height: 20),
          _label('Gender'),
          Wrap(
            spacing: 10,
            children: Gender.values.map((g) {
              final isSelected = _gender == g;
              return ChoiceChip(
                label: Text(g.label),
                selected: isSelected,
                onSelected: (_) => setState(() => _gender = g),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade300,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _label('Bio'),
          TextField(
            controller: bioController,
            maxLines: 3,
            maxLength: 300,
            decoration: _inputDecoration(
              hint: 'Ceritakan sedikit tentang kamu',
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepInterests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih ${InterestOptions.minSelected}-${InterestOptions.maxSelected} '
            'hal yang kamu suka.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          InterestSelector(
            selected: _interests,
            onChanged: (next) => setState(() => _interests = next),
          ),
        ],
      ),
    );
  }

  Widget _stepLocation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final profile = controller.me;
            final hasLocation = profile?.hasLocation ?? false;
            final locating = controller.isLocating.value;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasLocation
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasLocation
                      ? AppColors.green
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasLocation
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        color: hasLocation ? AppColors.primaryDeep : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasLocation
                              ? (profile?.city ?? 'Lokasi tersimpan')
                              : 'Lokasi belum diatur',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${profile!.latitude!.toStringAsFixed(4)}, '
                      '${profile.longitude!.toStringAsFixed(4)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: locating
                          ? null
                          : () => controller.refreshLocation(),
                      icon: locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        hasLocation
                            ? 'Perbarui lokasi'
                            : 'Aktifkan lokasi saya',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 28),
          const Text(
            'Filter Preferensi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bisa diubah kapan saja dari tab Profile.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _label('Tampilkan gender'),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _prefGender == null,
                onSelected: (_) => setState(() => _prefGender = null),
                selectedColor: AppColors.primary,
              ),
              ...Gender.values.map((g) => ChoiceChip(
                    label: Text(g.label),
                    selected: _prefGender == g,
                    onSelected: (_) => setState(() => _prefGender = g),
                    selectedColor: AppColors.primary,
                  )),
            ],
          ),
          const SizedBox(height: 20),
          _label('Rentang usia: '
              '${_ageRange.start.round()} - ${_ageRange.end.round()} tahun'),
          RangeSlider(
            values: _ageRange,
            min: 18,
            max: 60,
            divisions: 42,
            activeColor: AppColors.primaryDeep,
            labels: RangeLabels(
              '${_ageRange.start.round()}',
              '${_ageRange.end.round()}',
            ),
            onChanged: (v) => setState(() => _ageRange = v),
          ),
          const SizedBox(height: 12),
          _label('Jarak maksimal: ${_maxDistance.round()} km'),
          Slider(
            value: _maxDistance,
            min: 1,
            max: 200,
            divisions: 199,
            activeColor: AppColors.primaryDeep,
            label: '${_maxDistance.round()} km',
            onChanged: (v) => setState(() => _maxDistance = v),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => _goTo(_step - 1),
                  child: const Text('Kembali'),
                ),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: Obx(() {
                final busy = controller.isSaving.value;
                return ElevatedButton(
                  onPressed: busy ? null : _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          _step == _totalSteps - 1 ? 'Selesai' : 'Lanjut',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  InputDecoration _inputDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}