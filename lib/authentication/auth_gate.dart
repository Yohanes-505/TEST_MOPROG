import 'package:flutter/material.dart';
import 'package:Meetcha/authentication/welcome_screen.dart';
import 'package:Meetcha/home/main_shell.dart';
import 'package:Meetcha/profile/profile_setup_screen.dart';
import 'package:Meetcha/services/profile_service.dart';
import 'package:Meetcha/services/supabase_service.dart';
import 'package:Meetcha/services/session_timeout_service.dart';
import 'package:Meetcha/constants/app_colors.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// null = harus login, true = profil lengkap, false = belum lengkap
  Future<bool?> _resolve() async {
    final session = supabase.auth.currentSession;
    if (session == null) return null;

    if (await SessionTimeoutService.checkExpiredAndLogout()) return null;

    await SessionTimeoutService.touch();
    try {
      return await isProfileComplete(session.user.id);
    } catch (_) {
      return true; // offline: tetap masuk
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: _resolve(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snapshot.data;
        if (result == null) return const WelcomeScreen();
        return result ? const MainShell() : const ProfileSetupScreen();
      },
    );
  }
}