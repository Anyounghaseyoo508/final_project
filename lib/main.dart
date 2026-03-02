import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // เปลี่ยนจาก Firebase
import 'package:flutter_dotenv/flutter_dotenv.dart'; // สำหรับโหลด Key

import 'screens/login_screen.dart';
import 'screens/users/dashboard_screen.dart';
import 'screens/users/ai_tutor_screen.dart';
import 'screens/users/vocab_detail_screen.dart';
import 'screens/users/study_history_screen.dart';
import 'screens/admin/admin_exam_management_screen.dart';
import 'screens/admin/admin_add_question_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_import_screen.dart';
import 'screens/admin/admin_sheet_management_screen.dart';
import 'screens/admin/AdminVocabScreen.dart';
import 'screens/users/practice_exam_screen.dart';
import 'screens/users/exam_list_screen.dart';
import 'screens/users/games/games_menu_screen.dart';
import 'screens/users/games/game_leaderboard_screen.dart';
import 'screens/users/profile_screen.dart';
import 'screens/users/statistics_screen.dart';
import 'screens/admin/admin_monitoring_screen.dart';
import 'screens/admin/admin_user_management_screen.dart';
import 'screens/admin/admin_notification_screen.dart';
import 'screens/users/notification_center_screen.dart';

void main() async {
  // 1. ต้องมีบรรทัดนี้เพื่อให้ Flutter ทำงานกับ Native ได้ถูกต้อง
  WidgetsFlutterBinding.ensureInitialized();

  // 2. โหลดไฟล์ .env เพื่อเอาค่า URL และ Anon Key
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file. Make sure it exists.");
  }

  // 3. เริ่มต้นระบบ Supabase แทน Firebase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOEIC VocabBoost',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueAccent),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/admin_home': (context) => const AdminHomeScreen(),
        '/admin/exams': (context) => const AdminExamManagementScreen(),
        '/admin/add': (context) => const AdminAddQuestionScreen(),
        '/admin/import': (context) => const AdminImportScreen(),
        '/admin/sheets': (context) => const AdminSheetManagementScreen(),
        '/admin/vocab': (context) => const AdminVocabScreen(),
        '/admin/monitoring': (context) => const AdminMonitoringScreen(),
        '/admin/users': (context) => const AdminUserManagementScreen(),
        '/admin/notifications': (context) => const AdminNotificationScreen(),
        '/vocab-detail': (context) => const VocabDetailScreen(),
        '/': (context) => const UserDashboardScreen(),
        '/exam_list': (context) => const ExamListScreen(),
        '/games': (context) => const GamesMenuScreen(),
        '/games/leaderboard': (context) => const GameLeaderboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/statistics': (context) => const StatisticsScreen(),
        '/notifications': (context) => const NotificationCenterScreen(),
        '/practice_exam': (context) {
          final testId = ModalRoute.of(context)!.settings.arguments as int;
          return PracticeExamScreen(testId: testId);
        },
        '/ai-tutor': (context) => const AiTutorScreen(),
        '/study-history': (context) => const StudyHistoryScreen(),
      },
    );
  }
}
