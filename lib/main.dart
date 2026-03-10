import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/users/main_shell.dart';
import 'screens/users/ai_tutor_screen.dart';
import 'screens/users/Vocabulary Learning/vocab_detail_screen.dart';
import 'screens/users/Vocabulary Learning/bookmark_list_screen.dart';
import 'screens/users/Exam Practice/screens/study_history_screen.dart';
import 'screens/admin/Exam Management/screens/admin_exam_management_screen.dart';
import 'screens/admin/Exam Management/screens/admin_add_question_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_import_screen.dart';
import 'screens/admin/admin_sheet_management_screen.dart';
import 'screens/admin/Vocabbulary Management/screens/admin_vocab_screen.dart';
import 'screens/users/Exam Practice/screens/practice_exam_screen.dart';
import 'screens/users/games/games_menu_screen.dart';
import 'screens/users/games/game_leaderboard_screen.dart';
import 'screens/users/profile_screen.dart';
import 'screens/users/statistics_screen.dart';
import 'screens/users/notification_center_screen.dart';
import 'screens/admin/admin_monitoring_screen.dart';
import 'screens/admin/admin_user_management_screen.dart';
import 'screens/admin/admin_notification_screen.dart';
import 'services/app_theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file. Make sure it exists.');
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
          debugShowCheckedModeBanner: false,
          title: 'TOEIC VocabBoost',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A56DB),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F9FC),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1A56DB),
            ),
            brightness: Brightness.dark,
          ),
          themeMode: mode,
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/admin_home': (context) => const AdminHomeScreen(),
            '/admin': (context) => const AdminHomeScreen(),
            '/admin/exams': (context) => const AdminExamManagementScreen(),
            '/admin/add': (context) => const AdminAddQuestionScreen(),
            '/admin/import': (context) => const AdminImportScreen(),
            '/admin/sheets': (context) => const AdminSheetManagementScreen(),
            '/admin/vocab': (context) => const AdminVocabScreen(),
            '/admin/monitoring': (context) => const AdminMonitoringScreen(),
            '/admin/users': (context) => const AdminUserManagementScreen(),
            '/admin/notifications': (context) =>
                const AdminNotificationScreen(),
            '/vocab-detail': (context) => const VocabDetailScreen(),
            '/bookmarks': (context) => const BookmarkListScreen(),
            '/': (context) => const MainShell(),
            '/games': (context) => const GamesMenuScreen(),
            '/games/leaderboard': (context) => const GameLeaderboardScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/statistics': (context) => const StatisticsScreen(),
            '/notifications': (context) => const NotificationCenterScreen(),
            '/ai-tutor': (context) => const AiTutorScreen(),
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
