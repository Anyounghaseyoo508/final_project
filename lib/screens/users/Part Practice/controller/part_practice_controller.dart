import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Model: Result ────────────────────────────────────────────────────────────

class PartPracticeResult {
  final int part;
  final String title;
  final int? testId;
  final int totalQuestions;
  final int correctCount;
  final List<Map<String, dynamic>> questions;
  final Map<int, String> userAnswers;
  final DateTime submittedAt;

  PartPracticeResult({
    required this.part,
    required this.title,
    this.testId,
    required this.totalQuestions,
    required this.correctCount,
    required this.questions,
    required this.userAnswers,
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  double get percentage =>
      totalQuestions == 0 ? 0 : (correctCount / totalQuestions) * 100;

  int get wrongCount => totalQuestions - correctCount;
}

// ─── Model: Submission (สำหรับหน้าประวัติ) ───────────────────────────────────

class PartPracticeSubmission {
  final int id;
  final int part;
  final String title;
  final int correctCount;
  final int totalQuestions;
  final double percentage;
  final Map<String, String> answers;
  final DateTime submittedAt;
  final List<Map<String, dynamic>> questionsSnapshot;

  PartPracticeSubmission.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        part = (json['part'] as num).toInt(),
        title = json['title']?.toString() ?? '',
        correctCount = (json['correct_count'] as num?)?.toInt() ?? 0,
        totalQuestions = (json['total_questions'] as num?)?.toInt() ?? 0,
        percentage = (json['percentage'] as num?)?.toDouble() ?? 0,
        answers = Map<String, String>.from(
          (json['answers'] as Map? ?? {})
              .map((k, v) => MapEntry(k.toString(), v.toString())),
        ),
        submittedAt = DateTime.parse(json['submitted_at']).toLocal(),
        questionsSnapshot = json['questions_snapshot'] != null
            ? List<Map<String, dynamic>>.from(
                (json['questions_snapshot'] as List)
                    .map((q) => Map<String, dynamic>.from(q)),
              )
            : [];

  /// answers key=String → key=int สำหรับส่งให้ ResultScreen
  Map<int, String> get userAnswersInt =>
      answers.map((k, v) => MapEntry(int.tryParse(k) ?? 0, v));

  /// สร้าง PartPracticeResult จาก submission นี้ (เปิดหน้าเฉลยจากประวัติ)
  PartPracticeResult toResult() => PartPracticeResult(
        part: part,
        title: title,
        totalQuestions: totalQuestions,
        correctCount: correctCount,
        questions: questionsSnapshot,
        userAnswers: userAnswersInt,
        submittedAt: submittedAt,
      );

  String get gradeEmoji {
    if (percentage >= 90) return '🏆';
    if (percentage >= 80) return '🌟';
    if (percentage >= 70) return '👍';
    if (percentage >= 50) return '📚';
    return '💪';
  }

  Color gradeColor() {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }
}

// ─── Selector Controller ──────────────────────────────────────────────────────

class PartSelectorController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _disposed = false;

  bool isLoading = true;
  String? error;
  Map<int, List<String>> partTitles = {};
  List<int> availableParts = [];

  /// best score cache  key = '${part}_${title}'  value = percentage
  Map<String, double> bestScores = {};

  PartSelectorController() {
    _fetchMeta();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _fetchMeta() async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // ดึง test_id ที่ is_published = true จาก exam_sets ก่อน
      final publishedRows = await _supabase
          .from('exam_sets')
          .select('test_id')
          .eq('is_published', true);
      final publishedIds = (publishedRows as List)
          .map((r) => (r['test_id'] as num).toInt())
          .toList();

      if (publishedIds.isEmpty) {
        partTitles     = {};
        availableParts = [];
        bestScores     = {};
        isLoading      = false;
        _notify();
        return;
      }

      final futures = await Future.wait([
        _supabase
            .from('practice_test')
            .select('part, title, test_id')
            .inFilter('test_id', publishedIds)
            .order('part', ascending: true)
            .order('title', ascending: true),
        if (userId != null)
          _supabase
              .from('part_practice_submissions')
              .select('part, title, percentage')
              .eq('user_id', userId)
        else
          Future<List>.value([]),
      ]);

      // สร้าง partTitles
      final Map<int, Set<String>> seen = {};
      for (final row in futures[0]) {
        final int p = (row['part'] as num).toInt();
        final String t = row['title']?.toString() ?? 'Unknown';
        seen.putIfAbsent(p, () => {}).add(t);
      }
      partTitles = {
        for (final e in seen.entries) e.key: e.value.toList()..sort(),
      };
      availableParts = partTitles.keys.toList()..sort();

      // สร้าง bestScores (เอาสูงสุดของแต่ละ part+title)
      bestScores = {};
      for (final row in futures[1]) {
        final key = '${(row['part'] as num).toInt()}_${row['title']}';
        final pct = (row['percentage'] as num?)?.toDouble() ?? 0;
        if (!bestScores.containsKey(key) || bestScores[key]! < pct) {
          bestScores[key] = pct;
        }
      }

      isLoading = false;
      _notify();
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _notify();
    }
  }

  /// คะแนนสูงสุดที่เคยทำ (null = ยังไม่เคยทำ)
  double? getBestScore(int part, String title) =>
      bestScores['${part}_$title'];

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ─── Exam Controller ──────────────────────────────────────────────────────────

class PartPracticeController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final int selectedPart;
  final String selectedTitle;
  bool _disposed = false;

  PartPracticeController({
    required this.selectedPart,
    required this.selectedTitle,
  }) {
    _fetchQuestions();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool isLoading = true;
  bool isSaving = false;
  String? error;
  List<Map<String, dynamic>> questions = [];
  Map<int, String> userAnswers = {};
  int currentIndex = 0;
  bool isSubmitted = false;

  Map<String, dynamic>? get currentQuestion =>
      questions.isEmpty ? null : questions[currentIndex];

  bool get isLastQuestion => currentIndex >= questions.length - 1;

  bool get isAnswered => userAnswers.containsKey(currentIndex);

  Future<void> _fetchQuestions() async {
    try {
      // ตรวจว่า test_id นี้ is_published จริงก่อน
      final testRow = await _supabase
          .from('practice_test')
          .select('test_id')
          .eq('part', selectedPart)
          .eq('title', selectedTitle)
          .limit(1)
          .maybeSingle();

      if (testRow != null) {
        final tid = (testRow['test_id'] as num?)?.toInt();
        if (tid != null) {
          final pub = await _supabase
              .from('exam_sets')
              .select('is_published')
              .eq('test_id', tid)
              .maybeSingle();
          if (pub == null || pub['is_published'] != true) {
            error = 'ชุดข้อสอบนี้ยังไม่เปิดให้ใช้งาน';
            isLoading = false;
            _notify();
            return;
          }
        }
      }

      final results = await Future.wait([
        _supabase
            .from('practice_test')
            .select()
            .eq('part', selectedPart)
            .eq('title', selectedTitle)
            .order('question_no', ascending: true),
        _supabase
            .from('passages')
            .select()
            .order('sequence', ascending: true),
      ]);

      final rawQuestions = List<Map<String, dynamic>>.from(results[0]);
      final allPassages  = List<Map<String, dynamic>>.from(results[1]);

      // attach passages เข้าไปใน question ที่มี passage_group_id
      questions = rawQuestions.map((q) {
        final groupId = q['passage_group_id']?.toString() ?? '';
        if (groupId.isNotEmpty) {
          final grouped = allPassages
              .where((p) => p['passage_group_id']?.toString() == groupId)
              .toList();
          return {...q, 'passages': grouped};
        }
        return q;
      }).toList();

      isLoading = false;
      _notify();
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _notify();
    }
  }

  void selectAnswer(String key) {
    if (isSubmitted) return;
    userAnswers[currentIndex] = key;
    _notify();
  }

  void goNext() {
    if (currentIndex < questions.length - 1) {
      currentIndex++;
      _notify();
    }
  }

  void goBack() {
    if (currentIndex > 0) {
      currentIndex--;
      _notify();
    }
  }

  void goToIndex(int index) {
    if (index >= 0 && index < questions.length) {
      currentIndex = index;
      _notify();
    }
  }

  /// คำนวณผล → บันทึกลง DB → return PartPracticeResult
  Future<PartPracticeResult> submitExam() async {
    isSaving = true;
    _notify();

    int correct = 0;
    for (int i = 0; i < questions.length; i++) {
      final answer = userAnswers[i];
      if (answer != null && answer == questions[i]['correct_answer']) {
        correct++;
      }
    }

    final total = questions.length;
    final pct = total == 0 ? 0.0 : (correct / total) * 100;
    final testId = questions.isNotEmpty
        ? (questions.first['test_id'] as num?)?.toInt()
        : null;
    final now = DateTime.now();

    try {
      await _supabase.from('part_practice_submissions').insert({
        'user_id': _supabase.auth.currentUser?.id,
        'part': selectedPart,
        'title': selectedTitle,
        'test_id': testId,
        'correct_count': correct,
        'total_questions': total,
        'percentage': double.parse(pct.toStringAsFixed(2)),
        'answers': userAnswers.map((k, v) => MapEntry(k.toString(), v)),
        'questions_snapshot': questions, // ← บันทึกไว้เพื่อดูเฉลยย้อนหลัง
        'submitted_at': now.toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Save submission error: $e');
      // ไม่ block UI แม้ save ล้มเหลว — user ยังเห็นผลได้
    }

    isSubmitted = true;
    isSaving = false;
    _notify();

    return PartPracticeResult(
      part: selectedPart,
      title: selectedTitle,
      testId: testId,
      totalQuestions: total,
      correctCount: correct,
      questions: questions,
      userAnswers: userAnswers,
      submittedAt: now,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ─── History Controller ───────────────────────────────────────────────────────

class PartPracticeHistoryController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _disposed = false;

  bool isLoading = true;
  String? error;
  List<PartPracticeSubmission> submissions = [];
  int? filterPart; // null = ทุก Part

  PartPracticeHistoryController() {
    fetchHistory();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<PartPracticeSubmission> get filtered {
    if (filterPart == null) return submissions;
    return submissions.where((s) => s.part == filterPart).toList();
  }

  void setFilter(int? part) {
    filterPart = part;
    _notify();
  }

  Future<void> fetchHistory() async {
    isLoading = true;
    error = null;
    _notify();
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        submissions = [];
        isLoading = false;
        _notify();
        return;
      }
      final rows = await _supabase
          .from('part_practice_submissions')
          .select()
          .eq('user_id', userId)
          .order('submitted_at', ascending: false)
          .limit(20);

      submissions =
          (rows as List).map((r) => PartPracticeSubmission.fromJson(r)).toList();
      isLoading = false;
      _notify();
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _notify();
    }
  }

  // ── สถิติรวม ──
  int get totalAttempts => submissions.length;

  /// คะแนนเฉลี่ยแบบ weighted ตามจำนวนข้อ
  /// (ถูกทั้งหมด / ข้อทั้งหมด) × 100 — ไม่ใช่เฉลี่ย % ต่อ submission
  double get overallAverage {
    final total = totalQuestions;
    if (total == 0) return 0;
    return (totalCorrect / total) * 100;
  }

  int get totalCorrect =>
      submissions.fold(0, (sum, s) => sum + s.correctCount);

  int get totalQuestions =>
      submissions.fold(0, (sum, s) => sum + s.totalQuestions);

  /// Part ที่ทำบ่อยที่สุด
  int? get mostPracticedPart {
    if (submissions.isEmpty) return null;
    final count = <int, int>{};
    for (final s in submissions) {
      count[s.part] = (count[s.part] ?? 0) + 1;
    }
    return count.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// คะแนนสูงสุดของ part+title นั้น
  double? getBestScore(int part, String title) {
    final scores = submissions
        .where((s) => s.part == part && s.title == title)
        .map((s) => s.percentage);
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a > b ? a : b);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}