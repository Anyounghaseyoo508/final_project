import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import หน้าหลักใหม่
import 'screens/users/main_navigation_screen.dart'; // ✅ เพิ่ม Import นี้

import 'screens/login_screen.dart';
import 'screens/users/dashboard_screen.dart';
import 'screens/users/ai_tutor_screen.dart';
import 'screens/users/Vocabulary Learning/vocab_detail_screen.dart';
import 'screens/users/Vocabulary Learning/bookmark_list_screen.dart';
import 'screens/users/Exam Practice/study_history_screen.dart';
import 'screens/admin/admin_exam_management_screen.dart';
import 'screens/admin/admin_add_question_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_import_screen.dart';
import 'screens/admin/admin_sheet_management_screen.dart';
import 'screens/admin/AdminVocabScreen.dart';
import 'screens/users/Exam Practice/practice_exam_screen.dart';
import 'screens/users/Exam Practice/exam_list_screen.dart';
import 'screens/users/profile_screen.dart'; // ✅ เพิ่ม Import หน้าโปรไฟล์

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

  runApp(const MyApp());
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
        colorSchemeSeed: Colors.blueAccent,
        // เพิ่ม Font หรือการตั้งค่า Theme กลางตรงนี้ได้
      ),

      initialRoute: '/login',
      routes: {
        // --- Authentication ---
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),

        // --- User Section (ปรับปรุงใหม่) ---
        // เปลี่ยนหน้าแรกของ User ให้เป็น MainNavigation (ที่มี Navbar)
        '/': (context) => const MainNavigationScreen(), 
        '/dashboard': (context) => const UserDashboardScreen(),
        '/vocab-detail': (context) => const VocabDetailScreen(),
        '/exam_list': (context) => const ExamListScreen(),
        '/practice_exam': (context) {
          final testId = ModalRoute.of(context)!.settings.arguments as int;
          return PracticeExamScreen(testId: testId);
        },
        '/ai-tutor': (context) => const AiTutorScreen(),
        '/study-history': (context) => const StudyHistoryScreen(),
        '/bookmarks': (context) => const BookmarkListScreen(),
        '/profile': (context) => const ProfileScreen(), // ✅ เพิ่ม Route หน้าโปรไฟล์

        // --- Admin Section (ห้ามแก้ - คงไว้ตามเดิม) ---
        '/admin_home': (context) => const AdminHomeScreen(),
        '/admin/exams': (context) => const AdminExamManagementScreen(),
        '/admin/add': (context) => const AdminAddQuestionScreen(),
        '/admin/import': (context) => const AdminImportScreen(),
        '/admin/sheets': (context) => const AdminSheetManagementScreen(),
        '/admin/vocab': (context) => const AdminVocabScreen(),
      },
    );
  }
}