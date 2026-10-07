import 'dart:typed_data';

import 'package:bumble/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Avatar bulat yang bisa ditekan untuk memilih foto dari galeri/kamera.
/// Mengembalikan bytes + ekstensi lewat [onPicked] supaya aman di Web
/// maupun Android (tidak memakai dart:io).
class PhotoPickerAvatar extends StatelessWidget {
  final String? photoUrl;
  final Uint8List? localPreview;
  final bool isUploading;
  final void Function(Uint8List bytes, String extension) onPicked;
  final double radius;

  const PhotoPickerAvatar({
    super.key,
    required this.onPicked,
    this.photoUrl,
    this.localPreview,
    this.isUploading = false,
    this.radius = 56,
  });

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    onPicked(bytes, ext);
  }

  ImageProvider? get _image {
    if (localPreview != null) return MemoryImage(localPreview!);
    if (photoUrl != null && photoUrl!.startsWith('http')) {
      return NetworkImage(photoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: image,
            child: image == null
                ? Icon(Icons.person, size: radius, color: Colors.grey.shade500)
                : null,
          ),
          if (isUploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isUploading ? null : () => _pick(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.edit, size: 18, color: AppColors.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}