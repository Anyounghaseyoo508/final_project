import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _aiResponse = "";

  @override
  void initState() {
    super.initState();
    _getAiRecommendation();
  }

  Future<void> _getAiRecommendation() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. ดึงข้อมูลจุดอ่อน (3 หมวดที่คะแนนน้อยที่สุด)
      final skills = await _supabase
          .from('user_skills')
          .select()
          .eq('user_id', user.id)
          .order('correct_count', ascending: true)
          .limit(3);

      if (skills.isEmpty) {
        setState(() {
          _aiResponse = "ดูเหมือนคุณยังไม่มีประวัติการทำข้อสอบ ลองไปฝึกทำโจทย์ก่อน แล้วผมจะมาช่วยวิเคราะห์ให้นะครับ!";
          _isLoading = false;
        });
        return;
      }

      // 2. เตรียมข้อมูลส่งให้ Gemini
      String weaknessSummary = skills.map((s) {
        double percent = (s['correct_count'] / s['total_count']) * 100;
        return "- ${s['category']}: ทำคะแนนได้ ${percent.toStringAsFixed(0)}%";
      }).join("\n");

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
      );

      final prompt = """
      คุณคือติวเตอร์สอน TOEIC อัจฉริยะ 
      จากสถิติของผู้เรียน พบจุดอ่อนดังนี้:
      $weaknessSummary

      ช่วยวิเคราะห์และให้คำแนะนำตามนี้:
      1. สรุปภาพรวมว่าเขาควรโฟกัสที่หัวข้อไหนเป็นอันดับแรก
      2. อธิบายเทคนิคสั้นๆ สำหรับหัวข้อที่เขาอ่อนที่สุด (เช่น ถ้าอ่อน Tense ให้บอกเทคนิคการดู Keyword)
      3. ให้โจทย์ฝึกหัดหมวดที่เขาอ่อนที่สุด 1 ข้อ (พร้อมเฉลยและเหตุผล)
      
      ตอบด้วยภาษาที่เป็นกันเอง ให้กำลังใจ และใช้ Markdown ในการจัดรูปแบบให้สวยงาม
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      
      setState(() {
        _aiResponse = response.text ?? "AI ไม่สามารถวิเคราะห์ได้ในขณะนี้";
      });
    } catch (e) {
      setState(() {
        _aiResponse = "เกิดข้อผิดพลาดในการดึงข้อมูล: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Personal Tutor")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, size: 50, color: Colors.purple),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.purple.shade100)
                  ),
                  child: Text(_aiResponse), // แนะนำให้ใช้ package: flutter_markdown เพื่อความสวยงาม
                ),
              ],
            ),
          ),
    );
  }
}