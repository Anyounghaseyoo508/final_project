import 'package:flutter/material.dart';
import '../controller/explanation_detail_controller.dart';

class ExplanationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> question;
  final String userAns;
  final bool isCorrect;
  final Widget Function(Map<String, dynamic>) imageBuilder;

  const ExplanationDetailScreen({
    super.key,
    required this.question,
    required this.userAns,
    required this.isCorrect,
    required this.imageBuilder,
  });

  @override
  State<ExplanationDetailScreen> createState() =>
      _ExplanationDetailScreenState();
}

class _ExplanationDetailScreenState extends State<ExplanationDetailScreen> {
  // ── Controller (Logic อยู่ในนี้ทั้งหมด) ──────────────────────
  late final ExplanationDetailController _ctrl;

  // ── UI-only State ─────────────────────────────────────────────
  final PageController _pageController = PageController();
  final TextEditingController _chatController = TextEditingController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = ExplanationDetailController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    _ctrl.initGemini(
      question: widget.question,
      userAns: widget.userAns,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pageController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final imageUrls = _ctrl.getImageUrls(widget.question);

    return Scaffold(
      appBar: AppBar(title: Text("ข้อที่ ${widget.question['question_no']}")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (imageUrls.isNotEmpty) _buildImageSlider(imageUrls),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.question['question_text'] ?? "",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAnswerRow(),
                  const Divider(height: 40),
                  const Text(
                    "คำอธิบาย:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(widget.question['explanation'] ?? "-"),
                  const SizedBox(height: 30),
                  _buildAiButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildAnswerRow() {
    return Row(
      children: [
        _box(
          "คุณตอบ",
          widget.userAns,
          widget.isCorrect ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 10),
        _box("เฉลย", widget.question['correct_answer'], Colors.green),
      ],
    );
  }

  Widget _box(String t, String v, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(t, style: TextStyle(fontSize: 12, color: c)),
            Text(
              v,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _showChatBot(context),
        icon: const Icon(Icons.bolt),
        label: const Text("ถาม AI Tutor (สั้นกระชับ)"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildImageSlider(List<String> urls) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _pageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) =>
                InteractiveViewer(child: Image.network(urls[i])),
          ),
        ),
        Text(
          "${_currentPage + 1}/${urls.length}",
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CHATBOT BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────

  void _showChatBot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // ฟัง Controller ภายใน BottomSheet ด้วย
          _ctrl.addListener(() {
            if (context.mounted) setModalState(() {});
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
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
                    "AI TOEIC Tutor",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _ctrl.messages.isEmpty
                      ? _buildWelcomeView(setModalState)
                      : _buildChatMessageList(),
                ),
                if (_ctrl.isTyping) const LinearProgressIndicator(minHeight: 2),
                _buildChatInput(setModalState),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeView(StateSetter setModalState) {
    final suggestions = [
      "อธิบายข้อนี้ให้หน่อย",
      "ขอสรุป Grammar ข้อนี้",
      "แปลโจทย์และตัวเลือก",
      "ทำไมตัวเลือกอื่นถึงผิด",
    ];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 50,
                color: Colors.indigo.withOpacity(0.5),
              ),
              const SizedBox(height: 15),
              const Text(
                "สวัสดีครับ! อยากให้ช่วยอธิบายส่วนไหนเพิ่มเติมไหม?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 25),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: suggestions
                    .map(
                      (text) => ActionChip(
                        label: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.indigo,
                          ),
                        ),
                        backgroundColor: Colors.indigo.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(color: Colors.indigo.withOpacity(0.2)),
                        onPressed: () => _ctrl.sendMessage(text), // เรียก Controller
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessageList() {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _ctrl.messages.length,
      itemBuilder: (context, i) {
        final isUser = _ctrl.messages[i]['role'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? Colors.indigo : Colors.grey[100],
              borderRadius: BorderRadius.circular(15).copyWith(
                bottomRight: isUser ? Radius.zero : const Radius.circular(15),
                bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
              ),
            ),
            child: Text(
              _ctrl.messages[i]['text']!,
              style: TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatInput(StateSetter setModalState) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 15,
        left: 15,
        right: 15,
        top: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: "พิมพ์ถามเพิ่มเติม...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (v) {
                _ctrl.sendMessage(v); // เรียก Controller
                _chatController.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.indigo,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () {
                _ctrl.sendMessage(_chatController.text); // เรียก Controller
                _chatController.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
