import 'package:flutter/material.dart';
import 'explanation_detail_screen.dart';
import '../controller/exam_result_controller.dart';

class ExamResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final Map<dynamic, dynamic> userAnswers;
  final bool isHistoryView;
  final int durationSeconds;

  const ExamResultScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    this.isHistoryView = false,
    this.durationSeconds = 0,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  // ── Controller (Logic อยู่ในนี้ทั้งหมด) ──────────────────────
  late final ExamResultController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ExamResultController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    _ctrl.calculateAndFetchScores(
      questions: widget.questions,
      userAnswers: widget.userAnswers,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final prof        = _ctrl.getProficiencyData(_ctrl.totalScore);
    final cefrOverall  = _ctrl.getCefrLevel(_ctrl.totalScore, _ctrl.lToeic, _ctrl.rToeic);
    final cefrListening = _ctrl.getCefrListening(_ctrl.lToeic);
    final cefrReading   = _ctrl.getCefrReading(_ctrl.rToeic);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.questions.isNotEmpty
              ? (widget.questions.first['title'] ?? "Result Details")
              : "Result Details",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildScoreHeader(_ctrl.totalScore, prof, cefrOverall, cefrListening, cefrReading),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _scoreBox("Listening", _ctrl.lRaw, _ctrl.lToeic, Colors.orange.shade700),
                  const SizedBox(width: 15),
                  _scoreBox("Reading", _ctrl.rRaw, _ctrl.rToeic, Colors.green.shade700),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Review Answers",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.questions.length,
              itemBuilder: (context, index) {
                final q = widget.questions[index];
                final userAns =
                    widget.userAnswers[index] ??
                    widget.userAnswers[index.toString()] ??
                    "No Answer";
                final isCorrect = userAns == q['correct_answer'];
                return _buildQuestionCard(q, userAns, isCorrect);
              },
            ),
            const SizedBox(height: 40),
            _buildFinishButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WIDGETS
  // ─────────────────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  Widget _buildCefrSection(String overall, String listening, String reading) {
    final overallColor   = ExamResultController.cefrColor(overall);
    final listeningColor = ExamResultController.cefrColor(listening);
    final readingColor   = ExamResultController.cefrColor(reading);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // ── Overall (บน) ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall CEFR',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: overallColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        overall,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: overallColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            // ── Listening + Reading (ล่าง) ─────────────────────
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Listening', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          Text(
                            listening,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: listeningColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reading', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          Text(
                            reading,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: readingColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreHeader(int totalScore, Map<String, dynamic> prof,
      String cefrOverall, String cefrListening, String cefrReading) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Text(
            "Total Score",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          Text(
            "$totalScore",
            style: TextStyle(
              fontSize: 84,
              fontWeight: FontWeight.bold,
              color: prof['color'],
            ),
          ),
          Text(
            prof['title'],
            style: TextStyle(
              color: prof['color'],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            prof['desc'],
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildCefrSection(cefrOverall, cefrListening, cefrReading),
          if (widget.durationSeconds > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    'Time used: ${_formatDuration(widget.durationSeconds)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    Map<String, dynamic> q,
    String userAns,
    bool isCorrect,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExplanationDetailScreen(
                question: q,
                userAns: userAns,
                isCorrect: isCorrect,
                imageBuilder: _buildQuestionImages,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
          child: Text(
            "${q['question_no']}",
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text("Question ${q['question_no']} (Part ${q['part']})"),
        subtitle: Text(
          isCorrect ? "Correct" : "Incorrect Answer",
          style: TextStyle(
            color: isCorrect ? Colors.green : Colors.red,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildQuestionImages(Map<String, dynamic> q) {
    List<String> imageUrls = [];
    if (q['image_url'] != null && q['image_url'].toString().isNotEmpty) {
      imageUrls.add(q['image_url']);
    }
    if (q['passages'] != null && q['passages'] is List) {
      final List passages = q['passages'];
      passages.sort(
        (a, b) => (a['sequence'] ?? 0).compareTo(b['sequence'] ?? 0),
      );
      for (var p in passages) {
        if (p['image_url'] != null) imageUrls.add(p['image_url']);
      }
    }
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return Column(
      children: imageUrls
          .map(
            (url) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFinishButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          widget.isHistoryView ? "Back to History" : "Finish Review",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _scoreBox(String title, int raw, int scaled, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              "Raw: $raw/100",
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            const Divider(height: 20),
            Text(
              "$scaled",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Text(
              "Points",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}