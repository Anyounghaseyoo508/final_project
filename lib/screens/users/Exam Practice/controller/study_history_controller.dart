import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudyHistoryController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ─── Methods ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('exam_submissions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching history: $e");
      return [];
    }
  }

  /// ใช้ questions_snapshot ที่บันทึกตอนสอบ — ถูกต้องกว่าดึงใหม่จาก DB
  /// เพราะ index ของ userAnswers ตรงกับ snapshot ที่บันทึกไว้เสมอ
  List<Map<String, dynamic>> getQuestionsFromSnapshot(
      Map<String, dynamic> item) {
    try {
      final snapshot = item['questions_snapshot'];
      if (snapshot != null && snapshot is List && snapshot.isNotEmpty) {
        return List<Map<String, dynamic>>.from(
          snapshot.map((q) => Map<String, dynamic>.from(q)),
        );
      }
    } catch (e) {
      debugPrint('Error parsing snapshot: $e');
    }
    return [];
  }
}