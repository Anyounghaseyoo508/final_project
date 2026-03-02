import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ExplanationDetailController extends ChangeNotifier {
  // ─── State ───────────────────────────────────────────────────
  final List<Map<String, String>> messages = [];
  bool isTyping = false;

  // ─── Private ─────────────────────────────────────────────────
  late ChatSession _chatSession;
  late GenerativeModel _model;

  // ─── Init ─────────────────────────────────────────────────────
  void initGemini({
    required Map<String, dynamic> question,
    required String userAns,
  }) {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

    _chatSession = _model.startChat(
      history: [
        Content.text(
          """You are a TOEIC Tutor. 
      Question: ${question['question_text']}
      Correct: ${question['correct_answer']}
      User Answer: $userAns
      DB Explanation: ${question['explanation']}
      
      Instructions:
      1. ตอบเป็นภาษาไทย
      2. เน้นสั้น กระชับ ตรงประเด็น ไม่ต้องมีคำเกริ่นเยอะ
      3. ห้ามใช้เครื่องหมายหัวข้อเช่น # หรือ *** 4. อธิบายเหตุผลที่ตอบข้อนี้ และจุดที่คนตอบผิดบ่อย""",
        ),
      ],
    );
  }

  // ─── Methods ─────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    messages.add({"role": "user", "text": text});
    isTyping = true;
    notifyListeners();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      messages.add({
        "role": "model",
        "text": response.text?.replaceAll(RegExp(r'[*#]'), '') ?? "",
      });
    } catch (e) {
      debugPrint("Gemini error: $e");
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
