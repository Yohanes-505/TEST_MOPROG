import 'package:bumble/authentication/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';

import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:bumble/screens/chat_screen.dart';
import 'package:bumble/screens/match_screen.dart';
import 'package:bumble/services/match_chat_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'models/app_notification.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Background messaging hanya untuk mobile.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseBackgroundHandler,
    );
  }

  // Supabase
  await Supabase.initialize(
    url: 'https://xwhglyvwosyptwylskmt.supabase.co',
    publishableKey:
        'sb_publishable_IJ5sQ0p_YZrmMzSKS__o_Q_U61cdrQT',
  );

  // Push notification sementara hanya dijalankan di Android/iOS.
  // Chrome kita gunakan untuk development dan preview UI.
  if (!kIsWeb) {
    try {
      await initNotifications();
    } catch (e) {
      debugPrint('initNotifications gagal: $e');
    }
  }

  // Handle ketika user menekan notification.
  onNotificationTap = (AppNotification notif) {
    final nav = navigatorKey.currentState;

    if (nav == null) return;

    if (notif.type == AppNotificationType.match) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => const MatchChatScreen(),
        ),
      );

      return;
    }

    if (notif.type == AppNotificationType.message) {
      final matchId = notif.relatedId;

      if (matchId == null) return;

      MatchChatService()
          .getProfileForMatchId(matchId)
          .then((profile) {
        if (profile == null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => const MatchChatScreen(),
            ),
          );

          return;
        }

        nav.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              matchProfile: profile,
            ),
          ),
        );
      });
    }
  };

  // Global profile controller.
  Get.put(
    ProfileController(),
    permanent: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      title: 'Meetcha',
      theme: _meetchaTheme,
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
    );
  }
}

/// Tema global Meetcha.
/// Widget bawaan Flutter seperti Slider, Chip, ElevatedButton,
/// NavigationBar, dan ProgressIndicator mengikuti palette ini.
final ThemeData _meetchaTheme = ThemeData(
  useMaterial3: true,

  scaffoldBackgroundColor: AppColors.background,

  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.sage,
    primary: AppColors.primaryDeep,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primary,
    onPrimaryContainer: AppColors.onPrimary,
    secondary: AppColors.sage,
    onSecondary: AppColors.ink,
    error: AppColors.error,
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
    outline: AppColors.border,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.ink,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryDeep,
  ),

  chipTheme: ChipThemeData(
    selectedColor: AppColors.primary,
    checkmarkColor: AppColors.onPrimary,
    side: const BorderSide(
      color: AppColors.border,
    ),
  ),

  sliderTheme: const SliderThemeData(
    activeTrackColor: AppColors.primaryDeep,
    thumbColor: AppColors.primaryDeep,
    inactiveTrackColor: AppColors.primaryBorder,
  ),

  navigationBarTheme: const NavigationBarThemeData(
    indicatorColor: AppColors.primary,
    backgroundColor: AppColors.background,
  ),
);