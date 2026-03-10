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

  // ─── CEFR Level (ตามตาราง TOEIC official) ──────────────────────

  /// Overall CEFR — ต้องผ่านทั้ง total, listening, reading พร้อมกัน
  String getCefrLevel(int total, int listening, int reading) {
    if (total >= 945 && listening >= 490 && reading >= 455) return 'C1';
    if (total >= 785 && listening >= 400 && reading >= 385) return 'B2';
    if (total >= 550 && listening >= 275 && reading >= 275) return 'B1';
    if (total >= 225 && listening >= 110 && reading >= 115) return 'A2';
    if (total >= 120 && listening >= 60  && reading >= 60)  return 'A1';
    return 'Below A1';
  }

  /// CEFR เฉพาะ Listening
  String getCefrListening(int score) {
    if (score >= 490) return 'C1';
    if (score >= 400) return 'B2';
    if (score >= 275) return 'B1';
    if (score >= 110) return 'A2';
    if (score >= 60)  return 'A1';
    return 'Below A1';
  }

  /// CEFR เฉพาะ Reading
  String getCefrReading(int score) {
    if (score >= 455) return 'C1';
    if (score >= 385) return 'B2';
    if (score >= 275) return 'B1';
    if (score >= 115) return 'A2';
    if (score >= 60)  return 'A1';
    return 'Below A1';
  }

  /// สีประจำ CEFR level
  static Color cefrColor(String cefr) {
    switch (cefr) {
      case 'C1':       return const Color(0xFF3730A3); // indigo-700
      case 'B2':       return const Color(0xFF15803D); // green-700
      case 'B1':       return const Color(0xFF1D4ED8); // blue-700
      case 'A2':       return const Color(0xFFC2410C); // orange-700
      case 'A1':       return const Color(0xFFB91C1C); // red-700
      default:         return const Color(0xFF6B7280); // gray-500
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