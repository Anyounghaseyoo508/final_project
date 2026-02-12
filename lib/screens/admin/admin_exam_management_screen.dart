import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_add_question_screen.dart'; // ตรวจสอบให้แน่ใจว่า import ถูกต้อง

class AdminExamManagementScreen extends StatefulWidget {
  const AdminExamManagementScreen({super.key});

  @override
  State<AdminExamManagementScreen> createState() =>
      _AdminExamManagementScreenState();
}

class _AdminExamManagementScreenState extends State<AdminExamManagementScreen> {
  final _supabase = Supabase.instance.client;

  // สถานะการเจาะลึก: 0 = เลือก Test, 1 = เลือก Part, 2 = เลือกข้อ
  int _currentLevel = 0;
  int? _selectedTestId;
  int? _selectedPart;

  @override
  Widget build(BuildContext context) {
    // ใช้ PopScope (แทน WillPopScope ที่ deprecated ใน version ใหม่)
    return PopScope(
      canPop: _currentLevel == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentLevel > 0) {
          setState(() => _currentLevel--);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            _getDynamicTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: _currentLevel > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => setState(() => _currentLevel--),
                )
              : null,
          backgroundColor: Colors.blueAccent.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        body: _buildContent(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            // เมื่อเพิ่มเสร็จให้ Refresh หน้าจอ
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminAddQuestionScreen()),
            );
            setState(() {});
          },
          label: const Text("เพิ่มข้อสอบ"),
          icon: const Icon(Icons.add),
          backgroundColor: Colors.blueAccent.shade700,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  String _getDynamicTitle() {
    if (_currentLevel == 0) return "คลังข้อสอบ (Tests)";
    if (_currentLevel == 1) return "Test ชุดที่ $_selectedTestId";
    return "Test $_selectedTestId : Part $_selectedPart";
  }

  Widget _buildContent() {
    if (_currentLevel == 0) return _buildTestSelector();
    if (_currentLevel == 1) return _buildPartSelector();
    return _buildQuestionList();
  }

  IconData _getPartIcon(int part) {
    // TOEIC Part 1-4 คือ Listening, Part 5-7 คือ Reading
    if (part <= 4) {
      return Icons.headset; // ไอคอนหูฟังสำหรับการฟัง
    } else {
      return Icons.menu_book; // ไอคอนหนังสือสำหรับการอ่าน
    }
  }

  Color _getPartColor(int part) {
    return part <= 4 ? Colors.orange.shade700 : Colors.blue.shade700;
  }

  // --- เลเยอร์ 1: เลือก Test ID ---
  Widget _buildTestSelector() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabase.from('practice_test').select('test_id'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text("Error: ${snapshot.error}"));

        // กรองเอา Test ID ที่ไม่ซ้ำกัน
        final testIds =
            snapshot.data!.map((e) => e['test_id'] as int).toSet().toList()
              ..sort();

        if (testIds.isEmpty) return _buildEmptyState("ยังไม่มีชุดข้อสอบในระบบ");

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: testIds.length,
          itemBuilder: (context, index) {
            final tId = testIds[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.menu_book, color: Colors.white),
                ),
                title: Text(
                  "TOEIC Practice Test $tId",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text("เปิดเพื่อเลือก Part ด้านใน"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => setState(() {
                  _selectedTestId = tId;
                  _currentLevel = 1;
                }),
              ),
            );
          },
        );
      },
    );
  }

  // --- เลเยอร์ 2: เลือก Part (1-7) ---
  Widget _buildPartSelector() {
    final parts = List.generate(7, (i) => i + 1);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: parts.length,
      itemBuilder: (context, index) {
        final p = parts[index];
        //final isListening = p <= 4;
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPartColor(p).withOpacity(0.1),
              child: Icon(
                _getPartIcon(p), // เรียกใช้ฟังก์ชันไอคอน
                color: _getPartColor(p),
              ),
            ),
            title: Text(
              "Part $p: ${_getPartName(p)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(p <= 4 ? "Listening Section" : "Reading Section"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() {
                _selectedPart = p;
                _currentLevel = 2;
              });
            },
          ),
        );
      },
    );
  }

  // --- เลเยอร์ 3: รายการข้อสอบ (Question List) ---
  Widget _buildQuestionList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // แก้ไขตรงนี้: การใช้ stream พร้อม filter หลายตัว
      stream: _supabase
          .from('practice_test')
          .stream(primaryKey: ['id'])
          .order('question_no'),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        // กรองข้อมูลเฉพาะข้อสอบที่ตรงกับ Test ID และ Part ที่เลือกไว้
        final docs = snapshot.data!
            .where(
              (item) =>
                  item['test_id'] == _selectedTestId &&
                  item['part'] == _selectedPart,
            )
            .toList();

        if (docs.isEmpty) return _buildEmptyState("ยังไม่มีข้อสอบในพาร์ทนี้");

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = docs[index];
            final bool hasExplanation =
                item['explanation'] != null &&
                item['explanation'].toString().trim().isNotEmpty;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(
                  "ข้อที่ ${item['question_no']}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      item['question_text'] ?? "(ไม่มีโจทย์)",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        _badge(
                          hasExplanation
                              ? "มีเฉลยคำตอบแล้ว"
                              : "ยังไม่มีเฉลยคำตอบ",
                          hasExplanation ? Colors.purple : Colors.grey,
                        ),
                        if (item['audio_url'] != null &&
                            item['audio_url'] != "")
                          _badge("Audio", Colors.blue),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blue),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminAddQuestionScreen(editData: item),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(context, item['id']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getPartName(int part) {
    const names = [
      "Photographs",
      "Question-Response",
      "Conversations",
      "Short Talks",
      "Incomplete Sentences",
      "Text Completion",
      "Reading Comprehension",
    ];
    return names[part - 1];
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            msg,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: const Text(
          "ข้อมูลข้อสอบข้อนี้จะถูกลบออกจากฐานข้อมูลถาวร คุณแน่ใจหรือไม่?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabase.from('practice_test').delete().eq('id', id);
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                print("Delete error: $e");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "ลบข้อมูล",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
