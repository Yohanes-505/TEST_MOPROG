import 'package:Meetcha/constants/app_colors.dart';
import 'package:Meetcha/controllers/profile_controller.dart';
import 'package:Meetcha/models/profile_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Node flowchart: "Filter Preferensi (Usia, Jarak Max, Gender)".
/// Nilai di sini yang dipakai RPC `nearby_profiles` saat mengambil
/// "User Terdekat" di Swipe Hub.
class FilterPreferenceScreen extends StatefulWidget {
  const FilterPreferenceScreen({super.key});

  @override
  State<FilterPreferenceScreen> createState() =>
      _FilterPreferenceScreenState();
}

class _FilterPreferenceScreenState extends State<FilterPreferenceScreen> {
  final ProfileController controller = ProfileController.to;

  late Gender? _prefGender;
  late RangeValues _ageRange;
  late double _maxDistance;

  @override
  void initState() {
    super.initState();
    final p = controller.me;
    _prefGender = p?.prefGender;
    _ageRange = RangeValues(
      (p?.prefMinAge ?? 18).toDouble(),
      (p?.prefMaxAge ?? 35).toDouble(),
    );
    _maxDistance = (p?.prefMaxDistanceKm ?? 50).toDouble();
  }

  Future<void> _save() async {
    final ok = await controller.savePreferences(
      prefGender: _prefGender,
      minAge: _ageRange.start.round(),
      maxAge: _ageRange.end.round(),
      maxDistanceKm: _maxDistance.round(),
    );
    if (!ok) return;

    Get.back(result: true);
    Get.snackbar('Filter disimpan', 'Kartu swipe akan disesuaikan.',
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filter Preferensi')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Tampilkan gender',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _prefGender == null,
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => _prefGender = null),
              ),
              ...Gender.values.map((g) => ChoiceChip(
                    label: Text(g.label),
                    selected: _prefGender == g,
                    selectedColor: AppColors.primary,
                    onSelected: (_) => setState(() => _prefGender = g),
                  )),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Rentang usia: ${_ageRange.start.round()} - '
            '${_ageRange.end.round()} tahun',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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
          const SizedBox(height: 24),
          Text(
            'Jarak maksimal: ${_maxDistance.round()} km',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _maxDistance,
            min: 1,
            max: 200,
            divisions: 199,
            activeColor: AppColors.primaryDeep,
            label: '${_maxDistance.round()} km',
            onChanged: (v) => setState(() => _maxDistance = v),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final p = controller.me;
            if (p?.hasLocation == true) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Lokasi belum aktif. Filter jarak tidak akan bekerja.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.refreshLocation(),
                    child: const Text('Aktifkan'),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
          SizedBox(
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
                          'Simpan Filter',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                )),
          ),
        ],
      ),
    );
  }
}