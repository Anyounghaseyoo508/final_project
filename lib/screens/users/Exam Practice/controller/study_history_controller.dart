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

  /// ดึงข้อสอบ + รูป passage แบบ manual join แล้วคืนค่ากลับให้ UI navigate
  Future<List<Map<String, dynamic>>> fetchQuestionsWithPassages(
      int testId) async {
    // ขั้นตอนที่ 1: ดึงข้อสอบทั้งหมดของ test_id นี้
    final questionsResponse = await _supabase
        .from('practice_test')
        .select('*')
        .eq('test_id', testId)
        .order('question_no');

    List<Map<String, dynamic>> questions =
        List<Map<String, dynamic>>.from(questionsResponse);

    // ขั้นตอนที่ 2: รวบรวม passage_group_id ที่ต้องใช้ไปดึงรูป
    final groupIds = questions
        .map((q) => q['passage_group_id'])
        .where((id) => id != null)
        .toSet()
        .toList();

    if (groupIds.isNotEmpty) {
      // ดึงรูปภาพทั้งหมดจากตาราง passages ที่ตรงกับ groupIds
      final passagesResponse = await _supabase
          .from('passages')
          .select('*')
          .inFilter('passage_group_id', groupIds);

      final List<Map<String, dynamic>> allPassages =
          List<Map<String, dynamic>>.from(passagesResponse);

      // นำรูปภาพกลับมาใส่ในแต่ละข้อสอบ (Manual Join)
      for (var q in questions) {
        if (q['passage_group_id'] != null) {
          q['passages'] = allPassages
              .where((p) => p['passage_group_id'] == q['passage_group_id'])
              .toList();
        }
      }
    }

    return questions;
  }
}
