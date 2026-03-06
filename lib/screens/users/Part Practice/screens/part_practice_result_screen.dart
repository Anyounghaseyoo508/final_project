import 'package:flutter/material.dart';
import '../controller/part_practice_controller.dart';
import '../../Exam Practice/controller/explanation_detail_controller.dart';
import 'part_practice_selector_screen.dart';
class PartPracticeResultScreen extends StatefulWidget {
  final PartPracticeResult result;
  final bool isHistoryView;

  const PartPracticeResultScreen({
    super.key,
    required this.result,
    this.isHistoryView = false,
  });

  @override
  State<PartPracticeResultScreen> createState() =>
      _PartPracticeResultScreenState();
}

class _PartPracticeResultScreenState extends State<PartPracticeResultScreen> {
  // null = summary, int = index ของข้อที่ดูเฉลย
  int? _reviewIndex;

  // chatbot per-question: key = question index
  final Map<int, ExplanationDetailController> _chatCtrls = {};
  final TextEditingController _chatInputCtrl = TextEditingController();

  PartPracticeResult get r => widget.result;

  @override
  void dispose() {
    for (final c in _chatCtrls.values) {
      c.dispose();
    }
    _chatInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: _reviewIndex != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => setState(() => _reviewIndex = null),
              )
            : null,
        title: _reviewIndex == null
            ? Text(
                widget.isHistoryView ? 'ดูเฉลยย้อนหลัง' : 'ผลการทำข้อสอบ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : Row(children: [
                Expanded(
                  child: Text(
                    'เฉลยข้อ ${r.questions[_reviewIndex!]['question_no']}  ·  ${r.questions[_reviewIndex!]['category'] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ]),
      ),
      body: _reviewIndex == null ? _buildSummary() : _buildReview(_reviewIndex!),
    );
  }

  // ─── Summary Page ─────────────────────────────────────────────────────────
  Widget _buildSummary() {
    final pct = r.percentage;
    final color = pct >= 80
        ? Colors.green
        : pct >= 50
            ? Colors.orange
            : Colors.red;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Score card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.shade400, color.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'คะแนนของคุณ',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${r.correctCount}',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${r.totalQuestions}',
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getGradeText(pct),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _statCard('✅ ถูก', r.correctCount, Colors.green),
                const SizedBox(width: 12),
                _statCard(
                  '❌ ผิด',
                  r.totalQuestions - r.correctCount,
                  Colors.red,
                ),
                const SizedBox(width: 12),
                _statCard('📋 ทั้งหมด', r.totalQuestions, Colors.indigo),
              ],
            ),
          ),

          const Divider(height: 1),

          // Question list
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'รายละเอียดแต่ละข้อ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  'แตะเพื่อดูเฉลย',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: r.questions.length,
            itemBuilder: (_, i) => _buildQuestionRow(i),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _reviewIndex = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      '📖 ดูเฉลยทั้งหมด',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      if (widget.isHistoryView) {
                        // เปิดจากประวัติ → pop กลับหน้าประวัติ
                        Navigator.of(context).pop();
                      } else {
                        // เปิดจากหน้าสอบ → กลับไป Selector
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const PartPracticeSelectorScreen(),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      widget.isHistoryView
                          ? 'กลับหน้าประวัติ'
                          : 'กลับหน้าเลือก Part',
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

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionRow(int index) {
    final q = r.questions[index];
    final userAnswer = r.userAnswers[index];
    final correctAnswer = q['correct_answer']?.toString() ?? '';
    final isCorrect = userAnswer != null && userAnswer == correctAnswer;
    final notAnswered = userAnswer == null;

    return GestureDetector(
      onTap: () => setState(() => _reviewIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notAnswered
                ? Colors.grey.shade200
                : isCorrect
                    ? Colors.green.shade200
                    : Colors.red.shade200,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: notAnswered
                    ? Colors.grey.shade100
                    : isCorrect
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  notAnswered ? '—' : (isCorrect ? '✓' : '✗'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: notAnswered
                        ? Colors.grey
                        : isCorrect
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อ ${q['question_no']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'คุณตอบ: ${userAnswer ?? 'ไม่ได้ตอบ'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: notAnswered
                              ? Colors.grey
                              : isCorrect
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                      if (!isCorrect && !notAnswered) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• เฉลย: $correctAnswer',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  String _getGradeText(double pct) {
    if (pct >= 90) return '🏆 ยอดเยี่ยม!';
    if (pct >= 80) return '🌟 ดีมาก!';
    if (pct >= 70) return '👍 ดี';
    if (pct >= 50) return '📚 พอใช้';
    return '💪 ต้องฝึกเพิ่ม';
  }

  // ─── Review Page ──────────────────────────────────────────────────────────
  Widget _buildReview(int index) {
    final q = r.questions[index];
    final userAnswer = r.userAnswers[index];
    final correctAnswer = q['correct_answer']?.toString() ?? '';
    final isCorrect = userAnswer == correctAnswer;
    final partId = (q['part'] as num?)?.toInt() ?? 1;

    return Column(
      children: [
        // Navigation between review pages
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: index > 0
                    ? () => setState(() => _reviewIndex = index - 1)
                    : null,
                child: const Text('◀ ก่อนหน้า'),
              ),
              const Spacer(),
              Text(
                '${index + 1} / ${r.questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: index < r.questions.length - 1
                    ? () => setState(() => _reviewIndex = index + 1)
                    : null,
                child: const Text('ถัดไป ▶'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Result banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isCorrect ? '✅ ถูก' : '❌ ผิด',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        userAnswer != null
                            ? 'คุณตอบ: $userAnswer'
                            : 'ไม่ได้ตอบ',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'เฉลย: $correctAnswer',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Image
                if ((q['image_url']?.toString() ?? '').isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        q['image_url'],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
                    ),
                  ),

                // Transcript/Passage
                if ((q['transcript']?.toString() ?? '').isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.indigo.withOpacity(0.15)),
                    ),
                    child: Text(
                      q['transcript'],
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ],

                // Question
                if (partId != 6 &&
                    (q['question_text']?.toString() ?? '').isNotEmpty) ...[
                  Text(
                    q['question_text'],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Options with answer highlight
                ...['A', 'B', 'C', 'D'].map((key) {
                  final val = q['option_${key.toLowerCase()}'];
                  if (val == null || val.toString().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final isCorrectOpt = key == correctAnswer;
                  final isUserOpt = key == userAnswer;
                  final hideText = partId == 1 || partId == 2;

                  Color bgColor = Colors.white;
                  Color borderColor = Colors.grey.shade300;
                  Color circleColor = Colors.grey.shade200;
                  Color textColor = Colors.black87;

                  if (isCorrectOpt) {
                    bgColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    circleColor = Colors.green;
                    textColor = Colors.green;
                  } else if (isUserOpt && !isCorrectOpt) {
                    bgColor = Colors.red.shade50;
                    borderColor = Colors.red.shade300;
                    circleColor = Colors.red.shade300;
                    textColor = Colors.red;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: circleColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                key,
                                style: TextStyle(
                                  color: isCorrectOpt || isUserOpt
                                      ? Colors.white
                                      : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (!hideText) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                val.toString(),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: isCorrectOpt
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                          if (isCorrectOpt)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_circle,
                                  color: Colors.green, size: 18),
                            ),
                          if (isUserOpt && !isCorrectOpt)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.cancel,
                                  color: Colors.red, size: 18),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                // Explanation
                if ((q['explanation']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('💡 ', style: TextStyle(fontSize: 16)),
                            Text(
                              'เฉลยและอธิบาย',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          q['explanation'].toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildAiButton(index, q, r.userAnswers[index] ?? ''),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── AI Chatbot ───────────────────────────────────────────────────────────

  ExplanationDetailController _getOrCreateCtrl(
      int index, Map<String, dynamic> q, String userAns) {
    if (!_chatCtrls.containsKey(index)) {
      final ctrl = ExplanationDetailController();
      ctrl.initGemini(question: q, userAns: userAns);
      _chatCtrls[index] = ctrl;
    }
    return _chatCtrls[index]!;
  }

  Widget _buildAiButton(int index, Map<String, dynamic> q, String userAns) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _showChatBot(context, index, q, userAns),
        icon: const Icon(Icons.bolt),
        label: const Text('ถาม AI เพิ่มเติม'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showChatBot(BuildContext context, int index,
      Map<String, dynamic> q, String userAns) {
    final ctrl = _getOrCreateCtrl(index, q, userAns);
    _chatInputCtrl.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          ctrl.addListener(() {
            if (ctx.mounted) setModal(() {});
          });

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 5),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'AI TOEIC Tutor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ctrl.messages.isEmpty
                      ? _buildWelcomeView(ctrl)
                      : _buildChatList(ctrl, ctx),
                ),
                if (ctrl.isTyping) const LinearProgressIndicator(minHeight: 2),
                _buildChatInput(ctrl, ctx),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeView(ExplanationDetailController ctrl) {
    const suggestions = [
      'อธิบายข้อนี้ให้หน่อย',
      'ขอสรุป Grammar ข้อนี้',
      'แปลโจทย์และตัวเลือก',
      'ทำไมตัวเลือกอื่นถึงผิด',
    ];
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.auto_awesome,
                  size: 50, color: Colors.indigo.withOpacity(0.5)),
              const SizedBox(height: 15),
              const Text(
                'สวัสดีครับ! อยากให้ช่วยอธิบายส่วนไหนเพิ่มเติมไหม?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 25),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: suggestions
                    .map((text) => ActionChip(
                          label: Text(text,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.indigo)),
                          backgroundColor: Colors.indigo.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(
                              color: Colors.indigo.withOpacity(0.2)),
                          onPressed: () => ctrl.sendMessage(text),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(ExplanationDetailController ctrl, BuildContext ctx) {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: ctrl.messages.length,
      itemBuilder: (_, i) {
        final isUser = ctrl.messages[i]['role'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(12),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.75),
            decoration: BoxDecoration(
              color: isUser ? Colors.indigo : Colors.grey[100],
              borderRadius: BorderRadius.circular(15).copyWith(
                bottomRight:
                    isUser ? Radius.zero : const Radius.circular(15),
                bottomLeft:
                    isUser ? const Radius.circular(15) : Radius.zero,
              ),
            ),
            child: Text(
              ctrl.messages[i]['text']!,
              style:
                  TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatInput(ExplanationDetailController ctrl, BuildContext ctx) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 15,
        left: 15,
        right: 15,
        top: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatInputCtrl,
              decoration: InputDecoration(
                hintText: 'พิมพ์ถามเพิ่มเติม...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
              onSubmitted: (v) {
                ctrl.sendMessage(v);
                _chatInputCtrl.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.indigo,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () {
                ctrl.sendMessage(_chatInputCtrl.text);
                _chatInputCtrl.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}