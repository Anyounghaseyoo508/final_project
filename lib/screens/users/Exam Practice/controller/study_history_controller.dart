import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudyHistoryController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ─── Methods ─────────────────────────────────────────────────

  /// [filterDate] ถ้าไม่ส่งมา = ดึง 20 อันล่าสุด
  /// ถ้าส่งมา = ดึงเฉพาะวันนั้นทั้งหมด (00:00:00 - 23:59:59 UTC)
  Future<List<Map<String, dynamic>>> getHistory({DateTime? filterDate}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      var query = _supabase
          .from('exam_submissions')
          .select()
          .eq('user_id', user.id);

      if (filterDate != null) {
        // filter ตามวัน → ดึงทั้งหมดของวันนั้น
        final startLocal = DateTime(filterDate.year, filterDate.month, filterDate.day);
        final endLocal   = startLocal.add(const Duration(days: 1));
        final startUtc   = startLocal.toUtc().toIso8601String();
        final endUtc     = endLocal.toUtc().toIso8601String();

        final response = await query
            .gte('created_at', startUtc)
            .lt('created_at', endUtc)
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } else {
        // ไม่ได้ filter → ดึงแค่ 20 ล่าสุด
        final response = await query
            .order('created_at', ascending: false)
            .limit(20);

        return List<Map<String, dynamic>>.from(response);
      }
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