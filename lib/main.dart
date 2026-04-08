import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './splash_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/users/Exam Practice/screens/practice_exam_screen.dart';
import 'screens/users/Exam Practice/screens/study_history_screen.dart';
import 'screens/users/Vocabulary Learning/bookmark_list_screen.dart';
import 'screens/users/Vocabulary Learning/vocab_detail_screen.dart';
import 'screens/users/games/game_leaderboard_screen.dart';
import 'screens/users/games/games_menu_screen.dart';
import 'screens/users/main_shell.dart';
import 'screens/users/notification_center_screen.dart';
import 'screens/users/profile_screen.dart';
import 'screens/users/statistics_screen.dart';
import 'services/app_theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file.');
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _supabase = Supabase.instance.client;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _loadThemeFromSettings();
  }

  Future<void> _loadThemeFromSettings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('user_settings')
          .select('dark_mode')
          .eq('user_id', user.id)
          .maybeSingle();

      AppThemeService.setDarkMode(response?['dark_mode'] == true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeService.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'TOEIC VocabBoost',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A56DB),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F9FC),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A56DB),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: mode,
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/otp': (context) => const OtpScreen(),
            '/reset-password': (context) => const ResetPasswordScreen(),
            '/vocab-detail': (context) => const VocabDetailScreen(),
            '/bookmarks': (context) => const BookmarkListScreen(),
            '/': (context) => const MainShell(),
            '/games': (context) => const GamesMenuScreen(),
            '/games/leaderboard': (context) => const GameLeaderboardScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/statistics': (context) => const StatisticsScreen(),
            '/notifications': (context) => const NotificationCenterScreen(),
            '/study-history': (context) => const StudyHistoryScreen(),
            '/practice_exam': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              final testId = args is int ? args : 0;
              return PracticeExamScreen(testId: testId);
            },
          },
        );
      },
    );
  }
}
