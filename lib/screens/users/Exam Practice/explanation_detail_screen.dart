import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  final PageController _pageController = PageController();
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  late ChatSession _chatSession;
  late GenerativeModel _model;
  int _currentPage = 0;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initGemini();
  }

  void _initGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

    // ปรับ Prompt ให้สะอาดและสั่งให้ตอบสั้นกระชับ
    _chatSession = _model.startChat(
      history: [
        Content.text(
          """You are a TOEIC Tutor. 
      Question: ${widget.question['question_text']}
      Correct: ${widget.question['correct_answer']}
      User Answer: ${widget.userAns}
      DB Explanation: ${widget.question['explanation']}
      
      Instructions:
      1. ตอบเป็นภาษาไทย
      2. เน้นสั้น กระชับ ตรงประเด็น ไม่ต้องมีคำเกริ่นเยอะ
      3. ห้ามใช้เครื่องหมายหัวข้อเช่น # หรือ *** 4. อธิบายเหตุผลที่ตอบข้อนี้ และจุดที่คนตอบผิดบ่อย""",
        ),
      ],
    );
  }

  Future<void> _sendMessage(String text, StateSetter setModalState) async {
    if (text.trim().isEmpty) return;
    setModalState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _chatController.clear();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      setModalState(() {
        _messages.add({
          "role": "model",
          "text": response.text?.replaceAll(RegExp(r'[*#]'), '') ?? "",
        });
        _isTyping = false;
      });
    } catch (e) {
      setModalState(() => _isTyping = false);
    }
  }

  // --- UI Layout ---

  @override
  Widget build(BuildContext context) {
    final imageUrls = _getImageUrls();
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

  // ... (ฟังก์ชัน _getImageUrls และ _buildImageSlider เหมือนเดิมจากโค้ดก่อนหน้า) ...

  void _showChatBot(BuildContext context) {
    // ลบการเรียก _sendMessage อัตโนมัติออก เพื่อให้เปิดหน้าจอได้ทันที

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // ทำให้ขอบบนโค้งมนดูสวยงาม
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle Bar ส่วนหัวสำหรับดึงลง
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

              // เนื้อหาแชท
              Expanded(
                child: _messages.isEmpty
                    ? _buildWelcomeView(
                        setModalState,
                      ) // แสดงคำถามแนะนำถ้ายังไม่มีการคุย
                    : _buildChatMessageList(), // แสดงรายการแชทปกติ
              ),

              if (_isTyping) const LinearProgressIndicator(minHeight: 2),

              // ช่องกรอกข้อความ
              _buildChatInput(setModalState),
            ],
          ),
        ),
      ),
    );
  }

  // ส่วนแสดงคำถามแนะนำ (Suggested Questions)
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
                        onPressed: () => _sendMessage(text, setModalState),
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

  // ส่วนแสดงรายการข้อความแชท
  Widget _buildChatMessageList() {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final isUser = _messages[i]['role'] == 'user';
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
              _messages[i]['text']!,
              style: TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
          ),
        );
      },
    );
  }

  // ส่วนช่องป้อนข้อมูล
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
              onSubmitted: (v) => _sendMessage(v, setModalState),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.indigo,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () =>
                  _sendMessage(_chatController.text, setModalState),
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันดึงรูปภาพ (Copy จากเวอร์ชันก่อนหน้าได้เลย)
  List<String> _getImageUrls() {
    final Set<String> urlSet = {};
    if (widget.question['image_url'] != null &&
        widget.question['image_url'].toString().isNotEmpty)
      urlSet.add(widget.question['image_url']);
    if (widget.question['passages'] != null) {
      for (var p in widget.question['passages']) {
        if (p['image_url'] != null) urlSet.add(p['image_url']);
      }
    }
    return urlSet.toList();
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
}
