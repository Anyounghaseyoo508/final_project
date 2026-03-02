import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamResultController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ─── State ───────────────────────────────────────────────────
  bool isLoading = true;
  int lRaw   = 0;
  int rRaw   = 0;
  int lToeic = 0;
  int rToeic = 0;

  // ─── Getters ─────────────────────────────────────────────────
  int get totalScore => lToeic + rToeic;

  // ─── Methods ─────────────────────────────────────────────────
  // หน้าที่เดียวของ controller นี้คือ "คำนวณและแสดงผล" เท่านั้น
  // การ save ทั้งหมดทำใน practice_exam_controller.submitExam() แล้ว
  Future<void> calculateAndFetchScores({
    required List<Map<String, dynamic>> questions,
    required Map<dynamic, dynamic> userAnswers,
  }) async {
    int lCount = 0;
    int rCount = 0;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAns = userAnswers[i] ?? userAnswers[i.toString()];
      if (userAns != null && userAns == q['correct_answer']) {
        if ((q['part'] ?? 1) <= 4) lCount++; else rCount++;
      }
    }

    try {
      final results = await Future.wait([
        _supabase.from('toeic_conversion').select('listening_score')
            .eq('raw_score', lCount).maybeSingle(),
        _supabase.from('toeic_conversion').select('reading_score')
            .eq('raw_score', rCount).maybeSingle(),
      ]);

      lRaw   = lCount;
      rRaw   = rCount;
      lToeic = (results[0]?['listening_score'] as int?) ?? lCount;
      rToeic = (results[1]?['reading_score']   as int?) ?? rCount;

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
    }
  }

  // ─── Proficiency Level ────────────────────────────────────────
  Map<String, dynamic> getProficiencyData(int totalScore) {
    if (totalScore >= 905)
      return {
        "title": "International Professional Proficiency",
        "desc": "Able to communicate effectively in any situation.",
        "color": Colors.indigo.shade900,
      };
    if (totalScore >= 785)
      return {
        "title": "Working Proficiency Plus",
        "desc": "Able to satisfy most work requirements effectively.",
        "color": Colors.green.shade700,
      };
    if (totalScore >= 605)
      return {
        "title": "Limited Working Proficiency",
        "desc": "Able to satisfy most social and limited work demands.",
        "color": Colors.blue.shade700,
      };
    if (totalScore >= 405)
      return {
        "title": "Elementary Proficiency Plus",
        "desc": "Can maintain predictable face-to-face conversations.",
        "color": Colors.orange.shade800,
      };
    if (totalScore >= 255)
      return {
        "title": "Elementary Proficiency",
        "desc": "Functional but limited proficiency on familiar topics.",
        "color": Colors.deepOrange.shade700,
      };
    return {
      "title": "Basic Proficiency",
      "desc": "Able to satisfy immediate survival needs.",
      "color": Colors.red.shade800,
    };
  }
}
