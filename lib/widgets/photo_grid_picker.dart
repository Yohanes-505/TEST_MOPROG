import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:Meetcha/services/profile_service.dart'; 
import 'package:Meetcha/constants/app_colors.dart';

class PhotoGridPicker extends StatefulWidget {
  final String userId;
  final List<String> initialPhotos;
  final ProfileService profileService;
  final ValueChanged<List<String>>? onChanged;
  final ValueChanged<bool>? onBusyChanged;
  final double childAspectRatio;

  const PhotoGridPicker({
    super.key,
    required this.userId,
    required this.initialPhotos,
    required this.profileService,
    this.onChanged,
    this.onBusyChanged,
    this.childAspectRatio = 0.7,
  });

  @override
  State<PhotoGridPicker> createState() => _PhotoGridPickerState();
}

class _PhotoGridPickerState extends State<PhotoGridPicker> {
  final int maxPhotos = 6;
  late List<String> _photos;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.initialPhotos);
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _isLoading = value);
    widget.onBusyChanged?.call(value);
  }

  Future<void> _pickAndUploadPhoto() async {
    if (widget.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi tidak ditemukan. Silakan login ulang.')),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;

    _setLoading(true);

    try {
      final Uint8List bytes = await image.readAsBytes();
      // Sekarang nama filenya bisa tanpa ekstensi biar ga error pas upload
      final dot = image.name.lastIndexOf('.');
      final extension =
          dot == -1 ? 'jpg' : image.name.substring(dot + 1).toLowerCase();

      // Upload via service
      final newUrl = await widget.profileService.uploadPhoto(
        userId: widget.userId,
        bytes: bytes,
        fileExtension: extension,
      );

      if (mounted) {
        setState(() => _photos.add(newUrl));
        widget.onChanged?.call(List.of(_photos));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal upload foto. Coba lagi.')),
        );
      }
      debugPrint('UPLOAD PHOTO ERROR: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _deletePhoto(String url) async {
    if (_isLoading) return;
    _setLoading(true);

    try {
      await widget.profileService.deletePhoto(
        userId: widget.userId,
        photoUrl: url,
      );

      if (mounted) {
        setState(() => _photos.remove(url));
        widget.onChanged?.call(List.of(_photos));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus foto. Coba lagi.')),
        );
      }
      debugPrint('DELETE PHOTO ERROR: $e');
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), 
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, 
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: widget.childAspectRatio,
          ),
          itemCount: maxPhotos,
          itemBuilder: (context, index) {
            // kondisi Terisi Foto
            if (index < _photos.length) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _photos[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Ikon Hapus
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: IconButton(
                      onPressed: () => _deletePhoto(_photos[index]),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: AppColors.error, size: 16),
                      ),
                    ),
                  ),
                  // Label "Foto Utama"
                  if (index == 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary, 
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Utama',
                          style: TextStyle(color: AppColors.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            }

            // kondisi Tombol + ada slot
            if (index == _photos.length) {
              return GestureDetector(
                onTap: _isLoading ? null : _pickAndUploadPhoto,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryDeep, width: 2, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Icon(Icons.add_a_photo, size: 32, color: AppColors.primaryDeep),
                  ),
                ),
              );
            }

            // kondisi tidak ada slot
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
              ),
            );
          },
        ),

        // Loading Overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}