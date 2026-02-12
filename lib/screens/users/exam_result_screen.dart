import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
          _lToeic = lData != null
              ? (lData['listening_score'] as int)
              : (lRaw * 5).clamp(5, 495);
          _rToeic = rData != null
              ? (rData['reading_score'] as int)
              : (rRaw * 5).clamp(5, 495);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getProficiencyData(int totalScore) {
    if (totalScore >= 905) {
      return {
        "title": "International Professional Proficiency",
        "desc": "Able to communicate effectively in any situation.",
        "color": Colors.indigo.shade900,
      };
    } else if (totalScore >= 785) {
      return {
        "title": "Working Proficiency Plus",
        "desc": "Able to satisfy most work requirements effectively.",
        "color": Colors.green.shade700,
      };
    } else if (totalScore >= 605) {
      return {
        "title": "Limited Working Proficiency",
        "desc": "Able to satisfy most social and limited work demands.",
        "color": Colors.blue.shade700,
      };
    } else if (totalScore >= 405) {
      return {
        "title": "Elementary Proficiency Plus",
        "desc": "Can maintain predictable face-to-face conversations.",
        "color": Colors.orange.shade800,
      };
    } else if (totalScore >= 255) {
      return {
        "title": "Elementary Proficiency",
        "desc": "Functional but limited proficiency on familiar topics.",
        "color": Colors.deepOrange.shade700,
      };
    } else {
      return {
        "title": "Basic Proficiency",
        "desc": "Able to satisfy immediate survival needs.",
        "color": Colors.red.shade800,
      };
    }
  }

  void _showAiTutor(Map<String, dynamic> q, String userAns) {
    final TextEditingController chatController = TextEditingController();

    Future<String> getInitialAnalysis() async {
      try {
        final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
        if (apiKey.isEmpty) return "กรุณาติดตั้ง API Key ก่อนใช้งาน";

        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
        );
        final prompt =
            """
        You are a friendly TOEIC Expert Tutor. Analyze this question:
        Part: ${q['part']}
        Question: ${q['question'] ?? 'Audio Question'}
        Transcript/Context: ${q['transcript'] ?? 'No transcript available'}
        Options: A:${q['option_a']}, B:${q['option_b']}, C:${q['option_c']}, D:${q['option_d']}
        Correct Answer: ${q['correct_answer']}
        Student Answer: $userAns
        System Explanation: ${q['explanation'] ?? 'No explanation provided in system.'}

        Instructions:
        1. If the student was correct, congratulate them briefly and explain the key point.
        2. If incorrect, explain why their choice was wrong and why the correct one is right.
        3. Use friendly Thai language.
        4. Keep it concise but helpful.
        """;

        final response = await model.generateContent([Content.text(prompt)]);
        return response.text ?? "AI ไม่สามารถสร้างคำตอบได้";
      } catch (e) {
        return "เกิดข้อผิดพลาด: $e";
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: const Icon(Icons.psychology, color: Colors.indigo),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "AI Tutor Analysis",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 30),
              Expanded(
                child: FutureBuilder<String>(
                  future: getInitialAnalysis(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView(
                      controller: scrollController,
                      children: [
                        _buildChatBubble(
                          "AI Tutor",
                          snapshot.data ?? "ไม่มีข้อมูล",
                          false,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: TextField(
                  controller: chatController,
                  decoration: InputDecoration(
                    hintText: "Ask further questions...",
                    suffixIcon: const Icon(Icons.send, color: Colors.indigo),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(String sender, String text, bool isUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isUser ? Colors.indigo.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sender,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    int totalScore = _lToeic + _rToeic;
    final prof = _getProficiencyData(totalScore);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Result Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                  _scoreBox(
                    "Listening",
                    _lRaw,
                    _lToeic,
                    Colors.orange.shade700,
                  ),
                  const SizedBox(width: 15),
                  _scoreBox("Reading", _rRaw, _rToeic, Colors.green.shade700),
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

  Widget _buildScoreHeader(int totalScore, Map<String, dynamic> prof) {
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
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    Map<String, dynamic> q,
    String userAns,
    bool isCorrect,
  ) {
    final hasExp =
        q['explanation'] != null &&
        q['explanation'].toString().trim().isNotEmpty;
    final int part = q['part'] ?? 1;

    String questionDisplay = q['question'] ?? "";
    if (questionDisplay.isEmpty) {
      if (part == 1)
        questionDisplay = "Photographs (Look at the picture)";
      else if (part == 2)
        questionDisplay = "Question-Response (Listen to audio)";
      else
        questionDisplay = "Listen to the talk to answer";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCorrect
              ? Colors.green.shade50
              : Colors.red.shade50,
          child: Text(
            "${q['question_no']}",
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text("Question ${q['question_no']} (Part $part)"),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questionDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                _answerRow(
                  "Your Answer",
                  userAns,
                  isCorrect ? Colors.green : Colors.red,
                ),
                _answerRow(
                  "Correct Answer",
                  q['correct_answer'] ?? "-",
                  Colors.green,
                ),
                const Divider(height: 30),
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: Colors.indigo,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Explanation:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasExp)
                  Text(
                    q['explanation'],
                    style: const TextStyle(color: Colors.black87, height: 1.4),
                  )
                else
                  _buildNoExpWarning(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAiTutor(q, userAns),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text("Analyze with AI Tutor"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade50,
                      foregroundColor: Colors.indigo.shade900,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoExpWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "แอดมินยังไม่เพิ่มคำอธิบาย คลิกปุ่ม AI ด้านล่างเพื่อวิเคราะห์ได้เลย",
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
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
