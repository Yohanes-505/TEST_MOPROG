import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

bool isNetworkError(Object error) {
  if (error is PostgrestException) return false;
  if (error is TimeoutException) return true;

  final text = error.toString().toLowerCase();
  const markers = [
    'socketexception',
    'failed host lookup',
    'clientexception',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection timed out',
    'network is unreachable',
    'handshakeexception',
    'software caused connection abort',
    'websocketchannelexception',
    'authretryablefetchexception',
  ];
  return markers.any(text.contains);
}

String friendlyError(Object error) {
  if (isNetworkError(error)) {
    return 'Tidak bisa terhubung ke server. Periksa internet lalu coba lagi.';
  }

  if (error is PostgrestException) {
    final code = error.code ?? '-';
    switch (code) {
      case '42703': 
      case 'PGRST204':
        return 'Kolom tabel tidak cocok dengan aplikasi (kode $code): ${error.message}';
      case '42P01': 
      case 'PGRST205':
        return 'Tabel tidak ditemukan di database (kode $code): ${error.message}';
      case '42501': 
        return 'Akses ditolak oleh kebijakan database (RLS, kode 42501).';
      case 'PGRST116':
        return 'Data tidak ditemukan (kode PGRST116).';
      default:
        return 'Server menolak permintaan (kode $code): ${error.message}';
    }
  }

  if (error is AuthException) return error.message;
  if (error is StateError) return error.message;
  return 'Terjadi kesalahan. Coba lagi.';
}

Future<T> withRetry<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration timeout = const Duration(seconds: 10),
  Duration baseDelay = const Duration(milliseconds: 600),
}) async {
  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action().timeout(timeout);
    } catch (e) {
      if (attempt >= attempts || !isNetworkError(e)) rethrow;
      await Future<void>.delayed(baseDelay * attempt);
    }
  }
}
