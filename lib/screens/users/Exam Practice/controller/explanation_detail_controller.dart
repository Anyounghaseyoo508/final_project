import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExplanationDetailController extends ChangeNotifier {
  // ─── State ───────────────────────────────────────────────────
  final List<Map<String, String>> messages = [];
  bool isTyping = false;

  // ─── Private ─────────────────────────────────────────────────
  final _supabase = Supabase.instance.client;
  late Map<String, dynamic> _question;
  late String _userAns;

  // ─── Init ─────────────────────────────────────────────────────
  void initGemini({
    required Map<String, dynamic> question,
    required String userAns,
  }) {
    _question = question;
    _userAns = userAns;
  }

  // ─── Methods ─────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    messages.add({"role": "user", "text": text});
    isTyping = true;
    notifyListeners();

    try {
      // สร้าง prompt พร้อม context ของโจทย์
      final prompt = """You are a TOEIC Tutor. 
Question: ${_question['question_text']}
Correct: ${_question['correct_answer']}
User Answer: $_userAns
DB Explanation: ${_question['explanation']}

Instructions:
1. ตอบเป็นภาษาไทย
2. เน้นสั้น กระชับ ตรงประเด็น ไม่ต้องมีคำเกริ่นเยอะ
3. ห้ามใช้เครื่องหมายหัวข้อเช่น # หรือ ***
4. อธิบายเหตุผลที่ตอบข้อนี้ และจุดที่คนตอบผิดบ่อย

Previous messages: ${messages.map((m) => "${m['role']}: ${m['text']}").join('\n')}

User question: $text""";

      // เรียกผ่าน Supabase Edge Function แทน
      final response = await _supabase.functions.invoke(
        'gemini-chat',
        body: {'prompt': prompt},
      );
      debugPrint("Response status: ${response.status}");
      debugPrint("Response data: ${response.data}");
      if (response.status == 200) {
        final text = response.data['candidates'][0]['content']['parts'][0]['text'] as String;
        messages.add({
          "role": "model",
          "text": text.replaceAll(RegExp(r'[*#]'), ''),
        });
      } else {
        messages.add({"role": "model", "text": "เกิดข้อผิดพลาด กรุณาลองใหม่"});
      }
    } catch (e) {
      debugPrint("Gemini error: $e");
      messages.add({"role": "model", "text": "เกิดข้อผิดพลาด กรุณาลองใหม่"});
    } finally {
      isTyping = false;
      notifyListeners();
    }
  }

  List<String> getImageUrls(Map<String, dynamic> question) {
    final Set<String> urlSet = {};
    if (question['image_url'] != null &&
        question['image_url'].toString().isNotEmpty) {
      urlSet.add(question['image_url']);
    }
    if (question['passages'] != null) {
      for (var p in question['passages']) {
        if (p['image_url'] != null) urlSet.add(p['image_url']);
      }
    }
    return urlSet.toList();
  }
}