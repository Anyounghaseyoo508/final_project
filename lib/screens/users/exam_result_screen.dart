import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'explanation_detail_screen.dart'; // import หน้าใหม่

class ExamResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final Map<dynamic, dynamic> userAnswers;
  final bool isHistoryView;

  const ExamResultScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    this.isHistoryView = false,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  int _lRaw = 0;
  int _rRaw = 0;
  int _lToeic = 5;
  int _rToeic = 5;

  @override
  void initState() {
    super.initState();
    _calculateAndFetchScores();
  }

  Future<void> _calculateAndFetchScores() async {
    int lRaw = 0;
    int rRaw = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final userAns = widget.userAnswers[i] ?? widget.userAnswers[i.toString()];
      if (userAns != null && userAns == q['correct_answer']) {
        if ((q['part'] ?? 1) <= 4) {
          lRaw++;
        } else {
          rRaw++;
        }
      }
    }

    try {
      final lData = await _supabase
          .from('toeic_conversion')
          .select('listening_score')
          .eq('raw_score', lRaw)
          .maybeSingle();
      final rData = await _supabase
          .from('toeic_conversion')
          .select('reading_score')
          .eq('raw_score', rRaw)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _lRaw = lRaw;
          _rRaw = rRaw;
          _lToeic = lData != null ? (lData['listening_score'] as int) : (lRaw * 5).clamp(5, 495);
          _rToeic = rData != null ? (rData['reading_score'] as int) : (rRaw * 5).clamp(5, 495);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getProficiencyData(int totalScore) {
    if (totalScore >= 905) return {"title": "International Professional Proficiency", "desc": "Able to communicate effectively in any situation.", "color": Colors.indigo.shade900};
    if (totalScore >= 785) return {"title": "Working Proficiency Plus", "desc": "Able to satisfy most work requirements effectively.", "color": Colors.green.shade700};
    if (totalScore >= 605) return {"title": "Limited Working Proficiency", "desc": "Able to satisfy most social and limited work demands.", "color": Colors.blue.shade700};
    if (totalScore >= 405) return {"title": "Elementary Proficiency Plus", "desc": "Can maintain predictable face-to-face conversations.", "color": Colors.orange.shade800};
    if (totalScore >= 255) return {"title": "Elementary Proficiency", "desc": "Functional but limited proficiency on familiar topics.", "color": Colors.deepOrange.shade700};
    return {"title": "Basic Proficiency", "desc": "Able to satisfy immediate survival needs.", "color": Colors.red.shade800};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    int totalScore = _lToeic + _rToeic;
    final prof = _getProficiencyData(totalScore);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Result Details", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildScoreHeader(totalScore, prof),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _scoreBox("Listening", _lRaw, _lToeic, Colors.orange.shade700),
                  const SizedBox(width: 15),
                  _scoreBox("Reading", _rRaw, _rToeic, Colors.green.shade700),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Review Answers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.questions.length,
              itemBuilder: (context, index) {
                final q = widget.questions[index];
                final userAns = widget.userAnswers[index] ?? widget.userAnswers[index.toString()] ?? "No Answer";
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

  Widget _buildScoreHeader(int totalScore, Map<String, dynamic> prof) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Text("Total Score", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          Text("$totalScore", style: TextStyle(fontSize: 84, fontWeight: FontWeight.bold, color: prof['color'])),
          Text(prof['title'], style: TextStyle(color: prof['color'], fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Text(prof['desc'], style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, String userAns, bool isCorrect) {
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
          child: Text("${q['question_no']}", style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
        ),
        title: Text("Question ${q['question_no']} (Part ${q['part']})"),
        subtitle: Text(isCorrect ? "Correct" : "Incorrect Answer", style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildQuestionImages(Map<String, dynamic> q) {
    List<String> imageUrls = [];
    if (q['image_url'] != null && q['image_url'].toString().isNotEmpty) imageUrls.add(q['image_url']);
    if (q['passages'] != null && q['passages'] is List) {
      final List passages = q['passages'];
      passages.sort((a, b) => (a['sequence'] ?? 0).compareTo(b['sequence'] ?? 0));
      for (var p in passages) {
        if (p['image_url'] != null) imageUrls.add(p['image_url']);
      }
    }
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    return Column(
      children: imageUrls.map((url) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.contain)),
      )).toList(),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(widget.isHistoryView ? "Back to History" : "Finish Review", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _scoreBox(String title, int raw, int scaled, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Text("Raw: $raw/100", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            const Divider(height: 20),
            Text("$scaled", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const Text("Points", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}