import 'package:bumble/authentication/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/controllers/profile_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'models/app_notification.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
// import 'package:bumble/profile/profile_setup_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  await Supabase.initialize(
    url: 'https://xwhglyvwosyptwylskmt.supabase.co',
    publishableKey: 'sb_publishable_IJ5sQ0p_YZrmMzSKS__o_Q_U61cdrQT',
  );

    try {
    await initNotifications();
  } catch (e) {
    debugPrint('initNotifications gagal: $e');
  }

  onNotificationTap = (AppNotification notif) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (notif.type == AppNotificationType.match) {
      nav.pushNamed('/matches');
    } else if (notif.type == AppNotificationType.message) {
      nav.pushNamed('/chat', arguments: notif.relatedId);
    }
  };

  Get.put(ProfileController(), permanent: true);

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

/// Tema global Meetcha. Widget bawaan Flutter (Slider, Switch, Checkbox,
/// progress indicator, ElevatedButton, dll) otomatis mengikuti ini,
/// jadi warna tidak perlu diatur satu-satu di tiap layar.
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryDeep,
  ),
  chipTheme: ChipThemeData(
    selectedColor: AppColors.primary,
    checkmarkColor: AppColors.onPrimary,
    side: const BorderSide(color: AppColors.border),
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: AppColors.primaryDeep,
    thumbColor: AppColors.primaryDeep,
    inactiveTrackColor: AppColors.primaryBorder,
  ),
  navigationBarTheme: NavigationBarThemeData(
    indicatorColor: AppColors.primary,
    backgroundColor: AppColors.background,
  ),
);