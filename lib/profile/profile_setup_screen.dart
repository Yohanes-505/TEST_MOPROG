import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/constants/interest_options.dart';
import 'package:Meetcha/controllers/profile_controller.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:Meetcha/widgets/interest_selector.dart';
import 'package:Meetcha/widgets/photo_grid_picker.dart';
import 'package:Meetcha/services/profile_service.dart';
import 'package:Meetcha/verification/face_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

/// Node flowchart: "Profile Setup — Gender, Bio, Interest/Hobby Tags,
/// Preferensi & Lokasi GPS".
///
/// Dibagi jadi 4 langkah supaya tidak satu form panjang:
///   1. Foto          : upload foto (opsional, tanpa validasi)
///   2. Tentang kamu  : nama, umur, gender, bio (wajib)
///   3. Minat         : interest/hobby tags
///   4. Lokasi        : izin GPS + filter preferensi awal
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
  bool _photoBusy = false;
  bool _isFinishing = false;
  final _scrollController = ScrollController();
  final _nameKey = GlobalKey();
  final _ageKey = GlobalKey();
  final _genderKey = GlobalKey();
  String? _nameError;
  String? _ageError;
  String? _genderError;
  Gender? _gender;
  List<String> _interests = [];

  // Filter preferensi awal
  Gender? _prefGender;
  RangeValues _ageRange = const RangeValues(18, 35);
  double _maxDistance = 50;

  static const int _totalSteps = 4;

  @override
  void initState() {
    super.initState();
    _prefillFromAccount();
  }

  /// ProfileController dibuat di main() sebelum user login, jadi `me` bisa
  /// kosong / basi saat layar ini dibuka (terutama habis sign up). Muat ulang
  /// profil user yang sedang login, lalu isi nama dari profil atau metadata
  /// akun sebagai cadangan.
  Future<void> _prefillFromAccount() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    final metaName = (authUser?.userMetadata?['name'] as String?)?.trim() ?? '';
    if (metaName.isNotEmpty && nameController.text.isEmpty) {
      nameController.text = metaName;
    }

    await controller.loadProfile();
    if (!mounted) return;

    final me = controller.me;
    // Jangan menimpa kalau user sudah mulai mengetik.
    if (nameController.text.trim().isEmpty && (me?.name ?? '').isNotEmpty) {
      nameController.text = me!.name;
    }
    if (ageController.text.isEmpty && me?.age != null) {
      ageController.text = me!.age.toString();
    }
    if (bioController.text.isEmpty && (me?.bio ?? '').isNotEmpty) {
      bioController.text = me!.bio!;
    }
    setState(() {
      _gender ??= me?.gender;
      if (_interests.isEmpty && me != null) _interests = List.of(me.interests);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    nameController.dispose();
    ageController.dispose();
    bioController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // Validasi & navigasi antar langkah
  // ----------------------------------------------------------------

  String? _validateStepOne() {
    String? nameErr, ageErr, genderErr;

    if (nameController.text.trim().isEmpty) nameErr = 'Isi nama kamu dulu.';

    final ageText = ageController.text.trim();
    final age = int.tryParse(ageText);
    if (ageText.isEmpty) {
      ageErr = 'Isi umur kamu dulu.';
    } else if (age == null) {
      ageErr = 'Umur harus berupa angka.';
    } else if (age < 18) {
      ageErr = 'Kamu harus berusia minimal 18 tahun.';
    } else if (age > 100) {
      ageErr = 'Umur tidak valid.';
    }

    if (_gender == null) genderErr = 'Pilih gender kamu.';

    if (mounted) {
      setState(() {
        _nameError = nameErr;
        _ageError = ageErr;
        _genderError = genderErr;
      });
    }

    final firstError = nameErr ?? ageErr ?? genderErr;
    if (firstError != null) {
      final key = nameErr != null
          ? _nameKey
          : ageErr != null
              ? _ageKey
              : _genderKey;
      _scrollToField(key);
    }
    return firstError;
  }

  void _scrollToField(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
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
    FocusScope.of(context).unfocus();

    if (_photoBusy) {
      Get.snackbar('Tunggu sebentar', 'Foto kamu masih diproses.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Langkah 0 (foto) dibuat opsional sehingga bisa lanjut ke setup berikutnya.
    final error = switch (_step) {
      1 => _validateStepOne(),
      2 => _validateStepTwo(),
      _ => null,
    };
    if (error != null) {
      Get.snackbar('Belum lengkap', error,
          snackPosition: SnackPosition.TOP);
      return;
    }

    if (_step < _totalSteps - 1) {
      _goTo(_step + 1);
      return;
    }

    await _finish();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;

    // Ini buat validasi ulang, biar ga ada yang terlewat
    final errorOne = _validateStepOne();
    if (errorOne != null) {
      _goTo(1); // Ini buat selesain masalah ketika klik "lanjut" terdapat data yang belum lengkap sehingga direct ke profile setup no 1
      Get.snackbar('Belum lengkap', errorOne, snackPosition: SnackPosition.TOP);
      return;
    }
    final errorTwo = _validateStepTwo();
    if (errorTwo != null) {
      _goTo(2);
      Get.snackbar('Belum lengkap', errorTwo, snackPosition: SnackPosition.TOP);
      return;
    }

    final profile = controller.me;
    if (profile == null || !profile.hasLocation) {
      Get.snackbar(
        'Lokasi dibutuhkan',
        'Aktifkan lokasi dulu supaya kami bisa mencarikan orang di sekitarmu.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    _isFinishing = true;
    try {
      final saved = await controller.saveProfile(
        name: nameController.text.trim(),
        age: int.parse(ageController.text.trim()),
        bio: bioController.text.trim(),
        gender: _gender,
        interests: _interests,
      );
      if (!saved) return;

      final prefsSaved = await controller.savePreferences(
        prefGender: _prefGender,
        minAge: _ageRange.start.round(),
        maxAge: _ageRange.end.round(),
        maxDistanceKm: _maxDistance.round(),
      );
      if (!prefsSaved) return;

      await controller.loadProfile();

      Get.offAll(() => const FaceVerificationScreen(fromOnboarding: true));
    } finally {
      _isFinishing = false;
    }
  }

  // ----------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              _header(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepPhotos(),
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
      ),
    ),
  );
}

  Widget _header() {
  final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
  const titles = [
    'Foto Kamu',
    'Tentang Kamu',
    'Minat Kamu',
    'Lokasi & Preferensi',
  ];

  const subtitles = [
    'Tambahkan foto supaya profilmu lebih menarik.',
    'Bantu kami mengenalmu sedikit lebih dekat.',
    'Pilih hal-hal yang membuat kamu jadi dirimu.',
    'Atur siapa yang ingin kamu temui di sekitar kamu.',
  ];

  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Langkah ${_step + 1} dari $_totalSteps',
              style: const TextStyle(
                color: AppColors.matchaDeep,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            const Text(
              'MEETCHA',
              style: TextStyle(
                color: AppColors.sage,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: List.generate(_totalSteps, (i) {
            final active = i <= _step;

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 5,
                margin: EdgeInsets.only(
                  right: i == _totalSteps - 1 ? 0 : 7,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.matcha
                      : AppColors.matchaSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),

        if (!keyboardOpen) ...[
        const SizedBox(height: 24),

        Text(
          titles[_step],
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          subtitles[_step],
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        ],
      ],
    ),
  );
}

  Widget _stepPhotos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() => PhotoGridPicker(
                key: ValueKey(controller.me?.id ?? 'no-profile'),
                userId: const ProfileService().currentUserId ?? '',
                initialPhotos: controller.me?.photoUrls ?? const [],
                profileService: const ProfileService(),
                onBusyChanged: (busy) {
                  if (mounted) setState(() => _photoBusy = busy);
                },
              )),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Foto profil (opsional, tapi sangat disarankan).\nFoto pertama jadi foto utama.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepAboutYou() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data diri (wajib diisi)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _label('Nama', key: _nameKey),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            decoration: _inputDecoration(
              hint: 'Nama yang tampil di profil kamu',
              icon: Icons.person_outline,
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 20),
          _label('Umur', key: _ageKey),
          TextField(
            controller: ageController,
            onChanged: (_) {
              if (_ageError != null) setState(() => _ageError = null);
            },
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: _inputDecoration(
              hint: 'Masukkan umur kamu',
              icon: Icons.cake_outlined,
              errorText: _ageError,
            ),
          ),
          const SizedBox(height: 20),
          _label('Gender', key: _genderKey),
          Wrap(
            spacing: 10,
            children: Gender.values.map((g) {
              final isSelected = _gender == g;
              return ChoiceChip(
                label: Text(g.label),
                selected: isSelected,
                onSelected: (_) => setState(() {
                  _gender = g;
                  _genderError = null;
                }),
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
          if (_genderError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                _genderError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
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
  return Container(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
    decoration: const BoxDecoration(
      color: AppColors.background,
      border: Border(
        top: BorderSide(
          color: AppColors.border,
          width: 0.7,
        ),
      ),
    ),
    child: Row(
      children: [
        if (_step > 0)
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: () => _goTo(_step - 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.matchaDeep,
                  side: const BorderSide(
                    color: AppColors.primaryBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Kembali',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

        if (_step > 0) const SizedBox(width: 12),

        Expanded(
          flex: 2,
          child: SizedBox(
            height: 54,
            child: Obx(() {
              final busy = controller.isSaving.value || _photoBusy;

              return ElevatedButton(
                onPressed: busy ? null : _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.sage,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
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
                        _step == _totalSteps - 1
                            ? 'Selesai'
                            : 'Lanjut',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

  Widget _label(String text, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  InputDecoration _inputDecoration({
    required String hint,
    IconData? icon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}