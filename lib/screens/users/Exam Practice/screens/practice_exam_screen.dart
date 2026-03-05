import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../controller/practice_exam_controller.dart';
import './exam_result_screen.dart';
//import './practice_exam_screen.dart';
//import '../controller/practice_exam_controller.dart';

class PracticeExamScreen extends StatefulWidget {
  final int testId;
  const PracticeExamScreen({super.key, required this.testId});

  @override
  State<PracticeExamScreen> createState() => _PracticeExamScreenState();
}

class _PracticeExamScreenState extends State<PracticeExamScreen>
    with WidgetsBindingObserver {
  // ── Controller (Logic อยู่ในนี้ทั้งหมด) ──────────────────────
  late final PracticeExamController _ctrl;

  // ── UI-only State (เฉพาะสิ่งที่เป็นของ UI ล้วนๆ) ──────────────
  final PageController _passagePageController = PageController();
  int _currentPassagePage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = PracticeExamController(
      testId: widget.testId,
      onSubmitComplete: () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExamResultScreen(
              questions: _ctrl.questions,
              userAnswers: _ctrl.userAnswers,
              durationSeconds: _ctrl.elapsedSeconds,
            ),
          ),
        );
      },
    );
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    // เช็ค session ค้างก่อน แล้วค่อย fetch
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStart());
  }

  Future<void> _checkAndStart() async {
    final hasSession = await PracticeExamController.hasSavedSession(widget.testId);
    if (!mounted) return;

    if (hasSession) {
      final resume = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('มีข้อสอบค้างอยู่'),
          content: const Text('คุณต้องการทำต่อจากที่ค้างไว้ หรือเริ่มทำใหม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('เริ่มใหม่', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('ทำต่อ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (resume == false) {
        await PracticeExamController.clearSession();
      }
      _startExam(resume: resume ?? false);
    } else {
      _startExam(resume: false);
    }
  }

  void _startExam({required bool resume}) {
    _ctrl.fetchAllData(resume: resume).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading data: \$e")),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _passagePageController.dispose();
    super.dispose();
  }

  /// กลับมา foreground → แค่ notify controller ให้ timer display อัพเดท
  /// ไม่ setState ที่ screen ตรงๆ เพราะจะทำให้ audio reload
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _ctrl.notifyTimerUpdate();
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_ctrl.questions.isEmpty) {
      return const Scaffold(body: Center(child: Text("No questions found.")));
    }

    final partId = _ctrl.currentPartId;

    return PopScope(
      child: _ctrl.isShowingDirection
          ? _buildDirectionScreen(partId)
          : Scaffold(
              backgroundColor: Colors.grey[50],
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo,
                title: Text(
                  "Part $partId - ${_ctrl.questionTitle}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                actions: [
                  // ── Exam Countdown Timer ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _ctrl.isTimerWarning
                              ? Colors.red.shade50
                              : Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _ctrl.isTimerWarning
                                ? Colors.red.shade300
                                : Colors.indigo.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: _ctrl.isTimerWarning
                                  ? Colors.red
                                  : Colors.indigo,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _ctrl.examTimerDisplay,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _ctrl.isTimerWarning
                                    ? Colors.red
                                    : Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.grid_view_rounded),
                    onPressed: _showQuestionStatusSheet,
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (_ctrl.isListeningPart) _buildAudioControlBar(),
                  LinearProgressIndicator(
                    value: (_ctrl.currentIndex + 1) / _ctrl.questions.length,
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.indigo),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_ctrl.currentGroupQuestions.isNotEmpty)
                            _buildPassageContent(
                                _ctrl.currentGroupQuestions.first),
                          const SizedBox(height: 24),
                          if (_ctrl.currentGroupQuestions.isEmpty)
                            const Center(child: Text("Loading questions...")),
                          ..._ctrl.currentGroupQuestions.map((q) {
                            final actualIndex = _ctrl.questions.indexOf(q);
                            final qPartId =
                                (q['part'] as num?)?.toInt() ?? 1;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "No. ${actualIndex + 1}",
                                  style: TextStyle(
                                    color: Colors.indigo.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (q['part'] != 6)
                                  Text(
                                    q['question_text'] ?? "",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                _buildOption(actualIndex, "A", q['option_a'], qPartId),
                                _buildOption(actualIndex, "B", q['option_b'], qPartId),
                                _buildOption(actualIndex, "C", q['option_c'], qPartId),
                                _buildOption(actualIndex, "D", q['option_d'], qPartId),
                                const Divider(height: 40),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  _buildNavigationButtons(),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WIDGETS
  // ─────────────────────────────────────────────────────────────

  /// ตัวเลือกคำตอบ A/B/C/D
  Widget _buildOption(int qIndex, String key, String? value, int partId) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    final isSelected = _ctrl.userAnswers[qIndex] == key;
    final hideText = partId == 1 || partId == 2; // Part 1&2 ซ่อน option text

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _ctrl.selectAnswer(qIndex, key), // เรียก Controller
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    isSelected ? Colors.indigo : Colors.grey.shade200,
                child: Text(
                  key,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!hideText) ...[
                const SizedBox(width: 15),
                Expanded(
                    child: Text(value,
                        style: const TextStyle(fontSize: 16))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// แปลง Duration → M:SS (เช่น 0:00, 0:01, 1:23)
  String _formatAudioTime(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  /// แถบแสดงสถานะ Audio
  Widget _buildAudioControlBar() {
    final isPlaying = _ctrl.playerState == PlayerState.playing;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
            color: isPlaying ? Colors.indigo : Colors.grey,
            size: 30,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlaying ? "Listening Audio Playing..." : "Audio Standby",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPlaying ? Colors.indigo : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _ctrl.duration.inSeconds > 0
                        ? _ctrl.position.inSeconds / _ctrl.duration.inSeconds
                        : 0.0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.indigo),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Text(
            _formatAudioTime(_ctrl.position),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  /// Passage / รูปภาพประกอบข้อสอบ
  Widget _buildPassageContent(Map<String, dynamic> q) {
    final int partId = q['part'] ?? 1;

    if (partId == 6) {
      final transcript = q['transcript']?.toString() ?? "";
      if (transcript.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.withOpacity(0.1)),
        ),
        child: Text(transcript,
            style: const TextStyle(fontSize: 16, height: 1.6)),
      );
    }

    if (partId == 5) return const SizedBox.shrink();

    final groupId = q['passage_group_id']?.toString();

    if (groupId != null && groupId.isNotEmpty) {
      final groupImages = _ctrl.allPassageImages
          .where((img) => img['passage_group_id']?.toString() == groupId)
          .toList();

      if (groupImages.isNotEmpty) {
        return Column(
          children: [
            Container(
              height: 450,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _passagePageController,
                    itemCount: groupImages.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPassagePage = index),
                    itemBuilder: (context, index) {
                      final imageUrl =
                          groupImages[index]['image_url']?.toString() ?? "";
                      if (imageUrl.isEmpty) {
                        return const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.grey));
                      }
                      return InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 50, color: Colors.grey)),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child:
                                              CircularProgressIndicator())),
                        ),
                      );
                    },
                  ),
                  if (_currentPassagePage > 0)
                    _buildScrollButton(Icons.arrow_back_ios, () {
                      _passagePageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    }, isLeft: true),
                  if (_currentPassagePage < groupImages.length - 1)
                    _buildScrollButton(Icons.arrow_forward_ios, () {
                      _passagePageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    }, isLeft: false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Passage ${_currentPassagePage + 1} of ${groupImages.length}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 8),
          ],
        );
      }
    }

    if (_ctrl.currentGroupImageUrl != null &&
        _ctrl.currentGroupImageUrl!.isNotEmpty) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.network(
              _ctrl.currentGroupImageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(20),
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildScrollButton(IconData icon, VoidCallback onPressed,
      {required bool isLeft}) {
    return Positioned(
      left: isLeft ? 5 : null,
      right: isLeft ? null : 5,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
          child: IconButton(
              icon: Icon(icon, color: Colors.indigo), onPressed: onPressed),
        ),
      ),
    );
  }

  /// ปุ่ม Back / Next / Submit
  Widget _buildNavigationButtons() {
    final canGoBack = _ctrl.currentPartId >= 5;
    final isLastGroup = _ctrl.currentIndex +
            _ctrl.currentGroupQuestions.length >=
        _ctrl.questions.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (canGoBack)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  if (_ctrl.currentIndex > 0) {
                    final prevPart = _ctrl.questions[_ctrl.currentIndex - 1]['part'];
                    if (prevPart <= 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "ไม่สามารถย้อนกลับไปพาร์ท Listening ได้")),
                      );
                      return;
                    }
                    _ctrl.goBack(); // เรียก Controller
                  }
                },
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text("Back"),
              ),
            ),
          if (canGoBack) const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton(
              onPressed: _ctrl.isNavigating
                  ? null
                  : () async {
                      await _ctrl.handleNextStep(); // เรียก Controller
                      if (!mounted) return;
                      // ถ้า submit เสร็จ ให้ navigate ไปหน้าผล
                      if (_ctrl.questions.isNotEmpty &&
                          _ctrl.currentIndex + _ctrl.currentGroupQuestions.length >=
                              _ctrl.questions.length) {
                        // submitExam ถูกเรียกภายใน handleNextStep อยู่แล้ว
                        // แต่ต้อง navigate หลัง submit
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                isLastGroup ? "Submit" : "Next",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// หน้า Direction (แสดงก่อนเริ่ม Part ใหม่)
  Widget _buildDirectionScreen(int partId) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Exam Timer ──
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _ctrl.isTimerWarning
                      ? Colors.red.shade50
                      : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _ctrl.isTimerWarning
                        ? Colors.red.shade300
                        : Colors.indigo.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color:
                          _ctrl.isTimerWarning ? Colors.red : Colors.indigo,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _ctrl.examTimerDisplay,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _ctrl.isTimerWarning
                            ? Colors.red
                            : Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "PART $partId",
              style: const TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.w900,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 20),
            if (_ctrl.partDirections[partId]?['image_url'] != null)
              Expanded(
                child: Image.network(
                    _ctrl.partDirections[partId]!['image_url']),
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _ctrl.startQuestions(partId), // เรียก Controller
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  "START QUESTIONS",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Sheet แสดงแผนที่ข้อ
  void _showQuestionStatusSheet() {
    final currentPart = _ctrl.currentPartId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text("Question Map",
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusLegend(Colors.indigo, "Current"),
                const SizedBox(width: 15),
                _buildStatusLegend(Colors.green, "Answered"),
                const SizedBox(width: 15),
                _buildStatusLegend(Colors.grey.shade300, "Locked/Not Done"),
              ],
            ),
            const Divider(height: 30),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _ctrl.questions.length,
                itemBuilder: (context, index) {
                  final targetQ = _ctrl.questions[index];
                  final int targetPart = targetQ['part'] ?? 1;
                  final bool isAnswered =
                      _ctrl.userAnswers.containsKey(index);
                  final bool isCurrent = index == _ctrl.currentIndex;

                  bool isLocked = false;
                  if (currentPart <= 4 && !isCurrent) isLocked = true;
                  if (currentPart >= 5 && targetPart <= 4) isLocked = true;

                  return GestureDetector(
                    onTap: isLocked
                        ? null
                        : () {
                            // navigate โดยตรง (Reading เท่านั้น)
                            _ctrl.currentIndex = index;
                            _ctrl.isShowingDirection = false;
                            _ctrl.updateCurrentGroup();
                            _ctrl.loadAudio(isDirection: false);
                            Navigator.pop(context);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.indigo
                            : (isAnswered
                                ? Colors.green.shade100
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLocked
                              ? Colors.transparent
                              : Colors.indigo.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "${targetQ['question_no']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isLocked
                                ? Colors.grey.shade400
                                : (isCurrent
                                    ? Colors.white
                                    : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}