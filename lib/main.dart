import 'package:bumble/authentication/auth_gate.dart';
import 'package:bumble/authentication/welcome_screen.dart';
import 'package:bumble/widgets/meetcha_loading.dart';
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
import 'services/session_timeout_service.dart';
import 'services/supabase_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Animasi tampil minimal segini supaya tidak berkedip kalau init sangat cepat.
const Duration _minSplash = Duration(milliseconds: 1200);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Langsung tampilkan animasi; init berat dikerjakan di dalam _Bootstrap.
  runApp(const _Bootstrap());
}

/// Semua inisialisasi yang dulu ada di main().
Future<void> _initialize() async {
  final minShow = Future.delayed(_minSplash);

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

  await minShow;
}

/// Menampilkan animasi selama init berjalan, lalu berganti ke MyApp.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<void> _init = _initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const MyApp();
        }

        if (snapshot.hasError) {
          debugPrint('Init gagal: ${snapshot.error}');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.cream,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Gagal memulai aplikasi.\nPeriksa koneksi internetmu.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _init = _initialize()),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MeetchaLoadingScreen(),
        );
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (supabase.auth.currentSession == null) return;

    if (state == AppLifecycleState.paused) {
      SessionTimeoutService.touch(); // catat saat keluar
    } else if (state == AppLifecycleState.resumed) {
      SessionTimeoutService.checkExpiredAndLogout().then((expired) {
        if (expired) {
          Get.offAll(() => const WelcomeScreen());
        } else {
          SessionTimeoutService.touch();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      title: 'Meetcha',
      theme: _meetchaTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
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