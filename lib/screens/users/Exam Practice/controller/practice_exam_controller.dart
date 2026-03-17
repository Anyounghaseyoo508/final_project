import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// รวม Logic ทั้งหมดของหน้า PracticeExam ไว้ที่นี่
/// UI ไม่ต้องรู้จัก Supabase หรือ AudioPlayer โดยตรง
class PracticeExamController extends ChangeNotifier {
  // ─── Dependencies ───────────────────────────────────────────
  final int testId;
  final _supabase = Supabase.instance.client;
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Callback ที่ UI จะ listen เพื่อ navigate ไปหน้าผลสอบ
  VoidCallback? onSubmitComplete;

  PracticeExamController({required this.testId, this.onSubmitComplete}) {
    _initAudioListeners();
    // fetchAllData ถูกเรียกจาก screen หลังตัดสินใจ resume/fresh แล้ว
  }

  // ─── State ───────────────────────────────────────────────────
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> allPassageImages = [];
  Map<int, Map<String, dynamic>> partDirections = {};
  List<Map<String, dynamic>> currentGroupQuestions = [];

  int currentIndex = 0;
  final Map<int, String> userAnswers = {};
  bool isLoading = true;
  bool isShowingDirection = true;
  bool isNavigating = false;
  String? currentGroupImageUrl;
  bool _disposed = false;

  // คะแนนหลัง submit — ใช้ส่งต่อไปหน้า Result โดยไม่ต้องคิดซ้ำ
  int lRaw   = 0;
  int rRaw   = 0;
  int lToeic = 0;
  int rToeic = 0;

  // Audio State
  PlayerState playerState = PlayerState.stopped;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ─── Exam Timer (2 hours) ────────────────────────────────────
  static const Duration examDuration = Duration(hours: 2);
  Timer? _examTimer;
  DateTime? _examStartTime;

  /// เวลาที่เหลือ คำนวณจาก wall-clock จริง → นับ background ด้วย
  Duration get examTimeRemaining {
    if (_examStartTime == null) return examDuration;
    final elapsed = DateTime.now().difference(_examStartTime!);
    final remaining = examDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // SharedPreferences keys
  static const String _keyStartTime = 'exam_start_time';
  static const String _keyTestId    = 'exam_test_id';
  static const String _keyIndex     = 'exam_current_index';
  static const String _keyAnswers   = 'exam_answers';

  /// เช็คว่ามี session ค้างอยู่ของ testId นี้ไหม
  static Future<bool> hasSavedSession(int testId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_keyTestId);
    final savedTime = prefs.getString(_keyStartTime);
    if (savedId != testId || savedTime == null) return false;
    // เช็คว่า session ยังไม่หมดเวลา
    final start = DateTime.parse(savedTime);
    final elapsed = DateTime.now().difference(start);
    return elapsed < examDuration;
  }

  /// บันทึก session ปัจจุบันลง SharedPreferences
  Future<void> saveSession() async {
    if (_examStartTime == null || questions.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStartTime, _examStartTime!.toIso8601String());
    await prefs.setInt(_keyTestId, testId);
    await prefs.setInt(_keyIndex, currentIndex);
    await prefs.setString(
      _keyAnswers,
      jsonEncode(userAnswers.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  /// โหลด session ที่ค้างไว้ (เรียกหลัง fetchAllData เสร็จ)
  Future<void> _resumeSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getString(_keyStartTime);
    final savedIndex = prefs.getInt(_keyIndex) ?? 0;
    final savedAnswersRaw = prefs.getString(_keyAnswers);

    if (savedTime != null) {
      _examStartTime = DateTime.parse(savedTime);
    }
    if (savedIndex < questions.length) {
      currentIndex = savedIndex;
    }
    if (savedAnswersRaw != null) {
      final Map decoded = jsonDecode(savedAnswersRaw);
      userAnswers.clear();
      decoded.forEach((k, v) => userAnswers[int.parse(k)] = v.toString());
    }
    updateCurrentGroup();
  }

  /// ล้าง session ทิ้ง (เรียกตอน submit หรือ user เลือก "เริ่มใหม่")
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStartTime);
    await prefs.remove(_keyTestId);
    await prefs.remove(_keyIndex);
    await prefs.remove(_keyAnswers);
  }

  /// เริ่ม timer ใหม่ตั้งแต่ต้น
  void _startFreshTimer() {
    _examStartTime = DateTime.now();
    _resumeTimer();
  }

  /// เริ่ม tick loop (ใช้ทั้ง fresh และ resume)
  void _resumeTimer() {
    _examTimer?.cancel();
    _examTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (examTimeRemaining.inSeconds <= 0) {
        _examTimer?.cancel();
        submitExam();
      } else {
        _notify();
        saveSession(); // auto-save ทุก 1 วินาที
      }
    });
  }

  /// แสดงเป็น HH:MM:SS
  String get examTimerDisplay {
    final t = examTimeRemaining;
    final h = t.inHours.toString().padLeft(2, '0');
    final m = (t.inMinutes % 60).toString().padLeft(2, '0');
    final s = (t.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get isTimerWarning => examTimeRemaining.inMinutes < 10;

  /// เรียกจาก screen ตอน app กลับมา foreground — อัพเดท timer display เฉยๆ
  void notifyTimerUpdate() => _notify();

  /// เวลาที่ใช้สอบจริง (วินาที) — ใช้ส่งไปหน้า Result
  int get elapsedSeconds => _examStartTime != null
      ? DateTime.now().difference(_examStartTime!).inSeconds
      : 0;

  // ─── Getters (ใช้ใน UI บ่อย) ─────────────────────────────────
  Map<String, dynamic>? get currentQuestion =>
      questions.isEmpty ? null : questions[currentIndex];

  int get currentPartId => currentQuestion?['part'] ?? 1;

  bool get isListeningPart => currentPartId <= 4;

  String get questionTitle {
    if (currentGroupQuestions.length > 1) {
      final firstNo = currentGroupQuestions.first['question_no'];
      final lastNo = currentGroupQuestions.last['question_no'];
      return "Questions $firstNo-$lastNo";
    }
    return "Question ${currentQuestion?['question_no']}";
  }

  // ─── Audio ───────────────────────────────────────────────────
  void _initAudioListeners() {
    // ── ตรวจ endTime เพื่อ navigate ก่อนเสียงหมดไฟล์ (กรณีมี end_time ใน DB) ──
    _audioPlayer.onPositionChanged.listen((p) async {
      if (_disposed) return;
      if (questions.isEmpty || currentIndex >= questions.length || isNavigating) return;

      final currentQ = questions[currentIndex];
      final int partId = currentQ['part'] ?? 1;
      if (partId > 4) return;

      final directionData = partDirections[partId];
      if (directionData == null) return;

      // คำนวณ endTime — ถ้าไม่มีหรือ >= 9999 ปล่อยให้ onPlayerComplete จัดการ
      int? endTime;
      if (isShowingDirection) {
        final v = (directionData['end_time'] as num?)?.toInt();
        if (v != null && v < 9999) endTime = v;
      } else {
        final v = (currentGroupQuestions.isNotEmpty)
            ? (currentGroupQuestions.last['end_time'] as num?)?.toInt()
            : (currentQ['end_time'] as num?)?.toInt();
        if (v != null && v < 9999) endTime = v;
      }

      if (endTime != null && p.inSeconds >= endTime) {
        await _triggerAutoNext();
      }
    });

    // ── เสียงเล่นจบทั้งไฟล์ → navigate อัตโนมัติเสมอ ──
    _audioPlayer.onPlayerComplete.listen((_) async {
      if (_disposed) return;
      if (questions.isEmpty || currentIndex >= questions.length) return;
      final int partId = questions[currentIndex]['part'] ?? 1;
      if (partId <= 4) {
        await _triggerAutoNext();
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (_disposed) return;
      playerState = s;
      _notify();
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (_disposed) return;
      duration = d;
      _notify();
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (_disposed) return;
      position = p;
      _notify();
    });
  }

  /// navigate อัตโนมัติหลังเสียงจบ — ป้องกัน double-trigger ด้วย isNavigating
  Future<void> _triggerAutoNext() async {
    if (isNavigating || _disposed) return;
    isNavigating = true;
    _notify();
    try {
      await _audioPlayer.stop();
      await _autoHandleNextStep();
    } catch (e) {
      debugPrint("Auto-next error: $e");
      isNavigating = false;
      _notify();
    }
  }

  Future<void> loadAudio({required bool isDirection}) async {
    if (questions.isEmpty || currentIndex >= questions.length) {
      isNavigating = false;
      _notify();
      return;
    }

    final currentQ = questions[currentIndex];
    final int partId = currentQ['part'] ?? 1;

    // Reading ไม่มีเสียง
    if (partId >= 5) {
      try { await _audioPlayer.stop(); } catch (_) {}
      isNavigating = false;
      _notify();
      return;
    }

    final directionData = partDirections[partId];
    String? audioUrl;
    int startTime = 0;

    if (isDirection) {
      audioUrl = directionData?['audio_url'];
      startTime = (directionData?['start_time'] as num?)?.toInt() ?? 0;
    } else {
      audioUrl = (currentQ['audio_url']?.toString().isNotEmpty == true)
          ? currentQ['audio_url']
          : directionData?['audio_url'];
      startTime = (currentQ['start_time'] as num?)?.toInt() ?? 0;
    }

    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        await Future.delayed(const Duration(milliseconds: 100));
        await _audioPlayer.setSource(UrlSource(audioUrl));
        await _audioPlayer.seek(Duration(seconds: startTime));
        await _audioPlayer.resume(); // เล่นเสียงเสมอ ทั้ง direction และ question
      } catch (e) {
        debugPrint("Audio Playback Error: $e");
      } finally {
        // ปลด lock หลังเซ็ต source เสร็จ (ไม่ต้อง delay เพราะ onPlayerComplete จะ navigate ต่อ)
        isNavigating = false;
        _notify();
      }
    } else {
      isNavigating = false;
      _notify();
    }
  }

  Future<void> resumeAudio() => _audioPlayer.resume();

  // ─── Data Fetching ────────────────────────────────────────────
  Future<void> fetchAllData({bool resume = false}) async {
    try {
      final responses = await Future.wait([
        _supabase.from('part_directions').select(),
        _supabase
            .from('practice_test')
            .select()
            .eq('test_id', testId)
            .order('question_no', ascending: true),
        _supabase.from('passages').select().order('sequence', ascending: true),
      ]);

      partDirections = {
        for (var v in responses[0]) int.parse(v['part_id'].toString()): v,
      };
      final rawQuestions = List<Map<String, dynamic>>.from(responses[1]);
      allPassageImages = List<Map<String, dynamic>>.from(responses[2]);

      // Attach passages เข้าไปใน question แต่ละข้อ เพื่อให้ ExplanationDetailController ดึงรูปได้ครบ
      questions = rawQuestions.map((q) {
        final groupId = q['passage_group_id'];
        if (groupId != null && groupId.toString().isNotEmpty) {
          final passages = allPassageImages
              .where((p) => p['passage_group_id'] == groupId.toString())
              .toList();
          return {...q, 'passages': passages};
        }
        return q;
      }).toList();
      isLoading = false;
      currentIndex = 0;
      updateCurrentGroup();
      _notify();

      if (questions.isNotEmpty) {
        if (resume) {
          await _resumeSession();   // โหลด index, answers, startTime จาก prefs
          _resumeTimer();           // เดิน timer ต่อจาก startTime เดิม
          isShowingDirection = false;
          _notify();

          if (currentPartId <= 4) {
            // Listening: ถอยกลับไปข้อแรกของ group ที่ค้างไว้ แล้วเล่น audio ใหม่
            final groupId = questions[currentIndex]['passage_group_id'];
            if (groupId != null && groupId.toString().isNotEmpty) {
              // หา index แรกของ group นี้
              currentIndex = questions.indexWhere(
                (q) => q['passage_group_id'] == groupId,
              );
            }
            updateCurrentGroup();
            isNavigating = true;
            _notify();
            loadAudio(isDirection: false);
          } else {
            // Reading: กลับมาข้อที่ค้างไว้ได้เลย ไม่ต้องเล่น audio
            isNavigating = false;
            _notify();
          }
        } else {
          _startFreshTimer();       // เริ่ม timer ใหม่
          isNavigating = true;
          _notify();
          loadAudio(isDirection: true);
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      isLoading = false;
      _notify();
      rethrow; // ให้ UI จัดการแสดง SnackBar เอง
    }
  }

  // ─── Navigation ───────────────────────────────────────────────

  /// กด Next โดย user (manual) — guard isNavigating
  Future<void> handleNextStep() async {
    if (isNavigating) return;
    isNavigating = true;
    _notify();
    try {
      await _audioPlayer.stop();
      await _doNavigateNext();
    } catch (e) {
      debugPrint("Navigation Error: $e");
      isNavigating = false;
      _notify();
    }
  }

  /// เรียกจาก audio auto-next (_triggerAutoNext ตั้ง isNavigating=true ไว้แล้ว)
  Future<void> _autoHandleNextStep() async {
    try {
      await _doNavigateNext();
    } catch (e) {
      debugPrint("Auto Navigation Error: $e");
      isNavigating = false;
      _notify();
    }
  }

  /// Logic กลางสำหรับ navigate ไปข้อถัดไป
  Future<void> _doNavigateNext() async {
    if (_disposed) { isNavigating = false; return; }

    // ── กรณี Direction กำลังแสดงอยู่ → ปิด Direction แล้วเล่นข้อปัจจุบันทันที ──
    if (isShowingDirection) {
      isShowingDirection = false;
      _notify();
      // เล่นเสียงข้อแรกของ Part นี้ (currentIndex ไม่เปลี่ยน)
      await loadAudio(isDirection: false);
      return;
    }

    // ── กรณีปกติ → ไปข้อถัดไป ──
    final currentQ = questions[currentIndex];
    final int nextIndex = currentIndex + currentGroupQuestions.length;

    // จบข้อสอบทั้งหมด
    if (nextIndex >= questions.length) {
      isNavigating = false;
      _notify();
      await submitExam();
      return;
    }

    final nextQ = questions[nextIndex];
    currentIndex = nextIndex;
    updateCurrentGroup();

    // ขึ้น Part ใหม่ → แสดง Direction ก่อน
    if (nextQ['part'] != currentQ['part']) {
      isShowingDirection = true;
      _notify();
      await loadAudio(isDirection: true);
    } else {
      isShowingDirection = false;
      _notify();
      if ((nextQ['part'] as int? ?? 1) <= 4) {
        await loadAudio(isDirection: false);
      } else {
        isNavigating = false;
        _notify();
      }
    }
  }

  void goBack() {
    if (currentIndex <= 0) return;
    int prevIndex = currentIndex - 1;

    // วนถอยไปต้นกลุ่ม passage เดียวกัน
    while (prevIndex > 0 &&
        questions[prevIndex]['passage_group_id'] ==
            questions[prevIndex - 1]['passage_group_id']) {
      prevIndex--;
    }

    currentIndex = prevIndex;
    isShowingDirection = false;
    updateCurrentGroup();
    _notify();
  }

  void startQuestions(int partId) {
    isShowingDirection = false;
    _notify();
    loadAudio(isDirection: false).then((_) {
      if (partId <= 4) resumeAudio();
    });
  }

  // ─── Group / Passage ──────────────────────────────────────────
  void updateCurrentGroup() {
    if (questions.isEmpty) return;

    final currentQ = questions[currentIndex];
    final groupId = currentQ['passage_group_id'];

    if (groupId != null && groupId.toString().isNotEmpty) {
      currentGroupQuestions = questions
          .where((q) => q['passage_group_id'] == groupId)
          .toList();

      final firstWithImage = currentGroupQuestions.firstWhere(
        (q) => q['image_url'] != null && q['image_url'].toString().isNotEmpty,
        orElse: () => {},
      );
      currentGroupImageUrl = firstWithImage['image_url'];
    } else {
      currentGroupQuestions = [currentQ];
      currentGroupImageUrl = currentQ['image_url'];
    }
  }

  // ─── Answers ──────────────────────────────────────────────────
  void selectAnswer(int qIndex, String key) {
    userAnswers[qIndex] = key;
    _notify();
  }

  // ─── Submit ───────────────────────────────────────────────────
  // ── คำนวณ Proficiency Level จาก total TOEIC score ──────────────
  static String _proficiencyLevel(int total) {
    if (total >= 905) return 'International Professional Proficiency';
    if (total >= 785) return 'Working Proficiency Plus';
    if (total >= 605) return 'Limited Working Proficiency';
    if (total >= 405) return 'Elementary Proficiency Plus';
    if (total >= 255) return 'Elementary Proficiency';
    return 'Basic Proficiency';
  }

  Future<void> submitExam() async {
    int lRawCount = 0;
    int rRawCount = 0;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAnswer = userAnswers[i];
      final bool isCorrect = userAnswer != null && userAnswer == q['correct_answer'];
      if (isCorrect) {
        if ((q['part'] ?? 1) <= 4) lRawCount++; else rRawCount++;
      }
    }

    // ── แปลงคะแนนดิบ → TOEIC scaled score ───────────────────────
    final convResults = await Future.wait([
      _supabase.from('toeic_conversion').select('listening_score')
          .eq('raw_score', lRawCount).maybeSingle(),
      _supabase.from('toeic_conversion').select('reading_score')
          .eq('raw_score', rRawCount).maybeSingle(),
    ]);

    // บันทึกลง public fields เพื่อส่งต่อหน้า Result
    lRaw   = lRawCount;
    rRaw   = rRawCount;
    lToeic = (convResults[0]?['listening_score'] as int?) ?? lRawCount;
    rToeic = (convResults[1]?['reading_score']   as int?) ?? rRawCount;
    final total  = lToeic + rToeic;
    final level  = _proficiencyLevel(total);

    // ── คำนวณเวลาที่ใช้สอบ ───────────────────────────────────────
    final int durationSeconds = _examStartTime != null
        ? DateTime.now().difference(_examStartTime!).inSeconds
        : examDuration.inSeconds; // fallback กรณี start time หาย

    await _supabase.from('exam_submissions').insert({
      'user_id':            _supabase.auth.currentUser?.id,
      'test_id':            testId,
      'listening_raw':      lRaw,
      'reading_raw':        rRaw,
      'score':              lRaw + rRaw,
      'total_questions':    questions.length,
      'answers':            userAnswers.map((k, v) => MapEntry(k.toString(), v)),
      'questions_snapshot': questions,
      'l_toeic':            lToeic,
      'r_toeic':            rToeic,
      'total_score':        total,
      'cefr_level':         level,
      'duration_seconds':   durationSeconds,
    });

    // ล้าง session และแจ้ง UI
    await clearSession();
    onSubmitComplete?.call();
  }

  // ─── Dispose ──────────────────────────────────────────────────
  @override
  void dispose() {
    _disposed = true;
    _examTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }
}