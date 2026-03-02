import 'dart:math' show sqrt;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ── Category stat ──────────────────────────────────────────────────
class PartCategoryStat {
  final int part;
  final String partName;
  final String category;
  final int correct;
  final int total;
  final double accuracy;
  final double wilson;

  const PartCategoryStat({
    required this.part,
    required this.partName,
    required this.category,
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.wilson,
  });
}

// ── Part stat (รวม category ทุกตัวใน part นั้น) ────────────────────
class PartStat {
  final int part;
  final String partName;
  final int correct;
  final int total;
  final double accuracy;
  final double wilson;
  final List<PartCategoryStat> categories; // เรียงจากอ่อนสุด

  const PartStat({
    required this.part,
    required this.partName,
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.wilson,
    required this.categories,
  });
}

class AiTutorController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool isLoading    = true;
  bool isRefreshing = false;
  String aiResponse   = '';
  String errorMessage = '';

  List<PartStat> partStats = []; // ทุก part ที่มีข้อมูล เรียงจากอ่อนสุด
  List<PartStat> weakParts = []; // 3 part แรก

  Future<void> load() async {
    isLoading    = true;
    errorMessage = '';
    notifyListeners();
    await _fetchAndAnalyze();
  }

  Future<void> refresh() async {
    isRefreshing = true;
    errorMessage = '';
    notifyListeners();
    await _fetchAndAnalyze();
    isRefreshing = false;
    notifyListeners();
  }

  // ── Wilson Score Lower Bound (z=1.645, 95% CI) ─────────────────
  double _wilson(int correct, int total) {
    if (total == 0) return 0;
    const z  = 1.645;
    const z2 = z * z;
    final p  = correct / total;
    final n  = total.toDouble();
    final center = (p + z2 / (2 * n)) / (1 + z2 / n);
    final margin = (z / (1 + z2 / n)) *
                   sqrt(p * (1 - p) / n + z2 / (4 * n * n));
    return center - margin;
  }

  static const _partNames = {
    1: 'Part 1 – Photographs',
    2: 'Part 2 – Q&R',
    3: 'Part 3 – Conversations',
    4: 'Part 4 – Short Talks',
    5: 'Part 5 – Incomplete Sentences',
    6: 'Part 6 – Text Completion',
    7: 'Part 7 – Reading Comprehension',
  };

  Future<void> _fetchAndAnalyze() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      errorMessage = 'กรุณาเข้าสู่ระบบก่อน';
      isLoading    = false;
      notifyListeners();
      return;
    }

    try {
      // ── 1. ดึงข้อมูล 2 sources พร้อมกัน ──────────────────────────
      // A: user_skills — correct/total ต่อ category จาก full test
      // B: practice_test — mapping ว่า category อยู่ใน part ไหน
      final results = await Future.wait([
        _supabase
            .from('user_skills')
            .select('category, correct_count, total_count')
            .eq('user_id', user.id)
            .gt('total_count', 0),

        _supabase
            .from('practice_test')
            .select('part, category')
            .not('category', 'is', null)
            .neq('category', ''),
      ]);

      final rawSkills  = results[0] as List;
      final rawMapping = results[1] as List;

      if (rawSkills.isEmpty) {
        partStats  = [];
        weakParts  = [];
        aiResponse = '';
        isLoading  = false;
        notifyListeners();
        return;
      }

      // ── 2. Map: category → Set<part> จาก practice_test ───────────
      final categoryPartMap = <String, Set<int>>{};
      for (final r in rawMapping) {
        final cat  = r['category']?.toString().trim() ?? '';
        final part = (r['part'] as num?)?.toInt();
        if (cat.isEmpty || part == null) continue;
        categoryPartMap.putIfAbsent(cat, () => {}).add(part);
      }

      // ── 3. Map: category → [correct, total] จาก user_skills ───────
      final skillMap = <String, List<int>>{};
      for (final s in rawSkills) {
        final cat     = s['category']?.toString().trim() ?? '';
        final correct = (s['correct_count'] as num?)?.toInt() ?? 0;
        final total   = (s['total_count']   as num?)?.toInt() ?? 0;
        if (cat.isEmpty) continue;
        skillMap[cat] = [correct, total];
      }

      // ── 4. Build PartStat จาก skillMap + categoryPartMap ──────────
      // หา parts ทั้งหมดที่มี skill data
      final partMap = <int, List<PartCategoryStat>>{};
      for (final entry in skillMap.entries) {
        final cat     = entry.key;
        final correct = entry.value[0];
        final total   = entry.value[1];
        final parts   = categoryPartMap[cat] ?? {};

        for (final part in parts) {
          final stat = PartCategoryStat(
            part:     part,
            partName: _partNames[part] ?? 'Part $part',
            category: cat,
            correct:  correct,
            total:    total,
            accuracy: correct / total * 100,
            wilson:   _wilson(correct, total),
          );
          partMap.putIfAbsent(part, () => []).add(stat);
        }
      }

      // สร้าง PartStat โดยรวม correct/total จาก categories ในแต่ละ part
      final built = partMap.entries.map((e) {
        final part = e.key;
        final cats = e.value..sort((a, b) => a.wilson.compareTo(b.wilson));

        // รวม correct/total ระดับ part จาก categories (ไม่นับซ้ำถ้า category อยู่หลาย part)
        // ใช้ weighted sum ของ category ที่ map กับ part นี้
        final partCorrect = cats.fold(0, (s, c) => s + c.correct);
        final partTotal   = cats.fold(0, (s, c) => s + c.total);

        return PartStat(
          part:       part,
          partName:   _partNames[part] ?? 'Part $part',
          correct:    partCorrect,
          total:      partTotal,
          accuracy:   partTotal > 0 ? partCorrect / partTotal * 100 : 0,
          wilson:     _wilson(partCorrect, partTotal),
          categories: cats,
        );
      }).toList()
        ..sort((a, b) => a.wilson.compareTo(b.wilson));

      partStats = built;
      weakParts = built.take(3).toList();

      // ── 5. สร้าง prompt ──────────────────────────────────────────
      if (weakParts.isEmpty) {
        aiResponse = '';
        isLoading  = false;
        notifyListeners();
        return;
      }

      final partSummary = weakParts.map((p) {
        final acc      = p.accuracy.toStringAsFixed(0);
        final catLines = p.categories.take(3).map((c) =>
            '    • ${c.category}: ถูก ${c.correct}/${c.total} ข้อ '
            '(${c.accuracy.toStringAsFixed(0)})%').join('\n');
        return '- ${p.partName}: ความแม่นยำรวม $acc%\n$catLines';
      }).join('\n');

      final totalCorrect   = skillMap.values.fold(0, (s, v) => s + v[0]);
      final totalQuestions = skillMap.values.fold(0, (s, v) => s + v[1]);
      final overallAcc     = totalQuestions > 0
          ? (totalCorrect / totalQuestions * 100).toStringAsFixed(0)
          : '0';

      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        errorMessage = 'ไม่พบ GEMINI_API_KEY';
        isLoading    = false;
        notifyListeners();
        return;
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(temperature: 0.7),
      );

      // ประมาณจำนวนครั้งที่ทำ full test (200 ข้อต่อครั้ง)
      final examCount = totalQuestions > 0 ? (totalQuestions / 200).ceil() : 0;
      final sourceNote = examCount > 0
          ? 'ข้อสอบจำลอง $examCount ครั้ง รวม $totalQuestions ข้อ'
          : 'ข้อสอบจำลอง';

      final prompt = '''
คุณคือติวเตอร์ TOEIC ที่เป็นกันเอง ฉลาด และให้กำลังใจเสมอ

[ที่มาของข้อมูล: $sourceNote]
ถูก $totalCorrect/$totalQuestions ข้อ (ความแม่นยำรวม $overallAcc%)

[Part ที่อ่อน พร้อม Category breakdown]
$partSummary

ตอบเป็น 3 ส่วนสั้นๆ (ใช้ Markdown ไม่เกิน 300 คำ):

## 🎯 ควรฝึก Part ไหนก่อน
1-2 ประโยค บอก Part + เหตุผลจาก Category ที่อ่อน และแนะนำให้ไปฝึกรายพาร์ทในแอป

## 📚 เทคนิคสั้นๆ
2 เทคนิคสำหรับ Category ที่อ่อนที่สุด พร้อมตัวอย่าง 1 บรรทัด

## ✏️ โจทย์ฝึก 1 ข้อ
โจทย์ตรงกับ Part + Category ที่อ่อนสุด ตัวเลือก A-D พร้อมเฉลยสั้นๆ

ตอบภาษาไทย เป็นกันเอง กระชับ
''';

      final response = await model.generateContent([Content.text(prompt)]);
      aiResponse = response.text ?? 'AI ไม่สามารถวิเคราะห์ได้ในขณะนี้';

    } catch (e) {
      errorMessage = 'เกิดข้อผิดพลาด: $e';
      debugPrint('AiTutorController error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
