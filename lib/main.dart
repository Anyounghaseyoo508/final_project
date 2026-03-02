import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/login_screen.dart';
import 'screens/users/main_shell.dart'; // ① เพิ่ม
import 'screens/users/ai_tutor_screen.dart';
import 'screens/users/Vocabulary Learning/vocab_detail_screen.dart';
import 'screens/users/Vocabulary Learning/bookmark_list_screen.dart'; // ← เพิ่ม
import 'screens/users/Exam Practice/screens/study_history_screen.dart';
import 'screens/admin/Exam Management/screens/admin_exam_management_screen.dart';
import 'screens/admin/Exam Management/screens/admin_add_question_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_import_screen.dart';
import 'screens/admin/admin_sheet_management_screen.dart';
import 'screens/admin/Vocabbulary Management/screens/admin_vocab_screen.dart';
import 'screens/users/Exam Practice/screens/practice_exam_screen.dart';

// ลบ import ที่ MainShell จัดการแล้ว (ExamListScreen, GamesMenuScreen,
// ProfileScreen, UserDashboardScreen) — ไม่จำเป็นต้อง import ที่นี่อีก

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file. Make sure it exists.");
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const MyApp()); // ② ลบ ThemeProvider ออก
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOEIC VocabBoost',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A56DB)),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
      ),
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
        '/vocab-detail': (context) => const VocabDetailScreen(),
        '/bookmarks': (context) => const BookmarkListScreen(), // ← เพิ่ม
        '/': (context) => const MainShell(), // ③ เปลี่ยนตรงนี้
        '/ai-tutor': (context) => const AiTutorScreen(),
        '/study-history': (context) => const StudyHistoryScreen(),
        '/practice_exam': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final testId = args is int ? args : 0;
          return PracticeExamScreen(testId: testId);
        },
      },
    );
  }
}
