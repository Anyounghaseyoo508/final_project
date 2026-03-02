import 'package:flutter/material.dart';
import '../controller/part_practice_controller.dart';
import 'part_practice_exam_screen.dart';
import 'part_practice_history_screen.dart';

class PartPracticeSelectorScreen extends StatefulWidget {
  const PartPracticeSelectorScreen({super.key});

  @override
  State<PartPracticeSelectorScreen> createState() =>
      _PartPracticeSelectorScreenState();
}

class _PartPracticeSelectorScreenState
    extends State<PartPracticeSelectorScreen> {
  late PartSelectorController _ctrl;
  int? _selectedPart;

  static const Map<int, Map<String, dynamic>> _partInfo = {
    1: {
      'icon': Icons.image_outlined,
      'name': 'Photographs',
      'desc': 'เลือกประโยคที่ตรงกับรูปภาพ',
    },
    2: {
      'icon': Icons.record_voice_over_outlined,
      'name': 'Question-Response',
      'desc': 'เลือกคำตอบที่เหมาะสมที่สุด',
    },
    3: {
      'icon': Icons.forum_outlined,
      'name': 'Conversations',
      'desc': 'ฟังบทสนทนาแล้วตอบคำถาม',
    },
    4: {
      'icon': Icons.campaign_outlined,
      'name': 'Short Talks',
      'desc': 'ฟังการพูดแล้วตอบคำถาม',
    },
    5: {
      'icon': Icons.edit_note_outlined,
      'name': 'Incomplete Sentences',
      'desc': 'เติมคำในช่องว่าง',
    },
    6: {
      'icon': Icons.description_outlined,
      'name': 'Text Completion',
      'desc': 'เติมคำในบทความ',
    },
    7: {
      'icon': Icons.menu_book_outlined,
      'name': 'Reading Comprehension',
      'desc': 'อ่านบทความแล้วตอบคำถาม',
    },
  };

  @override
  void initState() {
    super.initState();
    _initCtrl();
  }

  void _initCtrl() {
    _ctrl = PartSelectorController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
        title: const Text(
          'แบบฝึกหัดรายพาร์ท',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'ประวัติการทำ',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PartPracticeHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _ctrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ctrl.error != null
              ? Center(child: Text('เกิดข้อผิดพลาด: ${_ctrl.error}'))
              : _selectedPart == null
                  ? _buildPartGrid()
                  : _buildTitleList(_selectedPart!),
    );
  }

  // ── หน้าเลือก Part ──────────────────────────────────────────────────────────
  Widget _buildPartGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'เลือก Part ที่ต้องการฝึก',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.1,
            ),
            itemCount: _ctrl.availableParts.length,
            itemBuilder: (context, i) {
              final part = _ctrl.availableParts[i];
              final info = _partInfo[part];
              final titleCount = _ctrl.partTitles[part]?.length ?? 0;
              return _buildPartCard(part, info, titleCount);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPartCard(int part, Map<String, dynamic>? info, int titleCount) {
    return InkWell(
      onTap: () => setState(() => _selectedPart = part),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade400, Colors.indigo.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              info?['icon'] ?? Icons.assignment_outlined,
              color: Colors.white,
              size: 28,
            ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Part $part',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    info?['name'] ?? 'Part $part',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info?['desc'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$titleCount ชุด',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── หน้าเลือกชุดข้อสอบ (Title) ─────────────────────────────────────────────
  Widget _buildTitleList(int part) {
    final info = _partInfo[part];
    final titles = _ctrl.partTitles[part] ?? [];

    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedPart = null),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.indigo,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Part $part — ${info?['name'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                    Text(
                      info?['desc'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'เลือกชุดข้อสอบ (${titles.length} ชุด)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: titles.length,
            itemBuilder: (context, i) {
              final title = titles[i];
              return _buildTitleCard(part, title, i);
            },
          ),
        ),
      ],
    );
  }

  // ── การ์ดชุดข้อสอบ (แสดงแค่ลำดับที่ ไม่มี % คะแนน) ───────────────────────
  Widget _buildTitleCard(int part, String title, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartPracticeExamScreen(part: part, title: title),
            ),
          ).then((_) {
            if (mounted) {
              _ctrl.dispose();
              _initCtrl();
              setState(() {});
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.indigo.withOpacity(0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── วงกลมลำดับที่ ──
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // ── ชื่อชุด ──
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.indigo.shade300),
            ],
          ),
        ),
      ),
    );
  }
}
