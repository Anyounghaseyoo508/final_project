import 'dart:async';

import 'package:flutter/material.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zrlzicxxyejlhbgotavi.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpybHppY3h4eWVqbGhiZ290YXZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAxOTIxNTQsImV4cCI6MjA4NTc2ODE1NH0.LohYIQrsIFQ7d7PtZl0GZEu3KyDu8mc-MW36UQjGcDk',
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A56DB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
      ),
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
  }
}