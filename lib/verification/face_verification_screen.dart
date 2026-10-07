import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'face_verification_service.dart';

class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  final _picker = ImagePicker();
  final _service = FaceVerificationService.instance;

  File? _image;
  FaceCheckResult? _result;
  bool _busy = false;

  Future<void> _takeSelfie() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
      maxWidth: 1080,
    );
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _busy = true;
    });

    try {
      final res = await _service.analyze(_image!);
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result =
          FaceCheckResult(passed: false, message: 'Gagal memproses foto: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_image == null || _result == null || !_result!.passed) return;
    setState(() => _busy = true);
    try {
      await _service.submit(_image!, _result!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akunmu sudah terverifikasi ✅')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim verifikasi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed = _result?.passed ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Wajah')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Ambil selfie sambil tersenyum lebar, hadap lurus ke kamera, dan pastikan hanya ada kamu di foto.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: _image == null
                      ? const Icon(Icons.face_retouching_natural,
                          size: 140, color: Colors.grey)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_image!, fit: BoxFit.cover),
                        ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                )
              else if (_result != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _result!.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: passed ? Colors.green : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _takeSelfie,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_image == null ? 'Ambil Selfie' : 'Ulangi Selfie'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (!_busy && passed) ? _submit : null,
                  child: const Text('Kirim Verifikasi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}