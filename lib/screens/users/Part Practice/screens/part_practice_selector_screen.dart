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

  // ── Palette ─────────────────────────────────────────────────────────────
  static const _bg      = Color(0xFFF8F9FB);
  static const _surface = Color(0xFFFFFFFF);
  static const _indigo  = Color(0xFF4F46E5);
  static const _indigoL = Color(0xFFEEF2FF);
  static const _border  = Color(0xFFE5E7EB);
  static const _textPri = Color(0xFF111827);
  static const _textSec = Color(0xFF6B7280);

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _indigo,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectedPart == null
              ? const Text(
                  'แบบฝึกหัดรายพาร์ท',
                  key: ValueKey('main'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                )
              : Row(
                  key: const ValueKey('detail'),
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedPart = null),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Part $_selectedPart — ${_partInfo[_selectedPart]?['name'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
        ),
        actions: [
          if (_selectedPart == null)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'ประวัติการทำ',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PartPracticeHistoryScreen()),
              ),
            ),
        ],
      ),
      body: _ctrl.isLoading
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _ctrl.error != null
              ? Center(
                  child: Text('เกิดข้อผิดพลาด: ${_ctrl.error}',
                      style: const TextStyle(color: _textSec)))
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _selectedPart == null
                      ? _buildPartGrid()
                      : _buildTitleList(_selectedPart!),
                ),
    );
  }

  // ── Part Grid ─────────────────────────────────────────────────────────────
  Widget _buildPartGrid() {
    return ListView(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'เลือก Part ที่ต้องการฝึก',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textSec,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
          ),
          itemCount: _ctrl.availableParts.length,
          itemBuilder: (context, i) {
            final part = _ctrl.availableParts[i];
            final info = _partInfo[part];
            final titleCount = _ctrl.partTitles[part]?.length ?? 0;
            return _PartCard(
              part: part,
              info: info,
              titleCount: titleCount,
              onTap: () => setState(() => _selectedPart = part),
            );
          },
        ),
      ],
    );
  }

  // ── Title List ────────────────────────────────────────────────────────────
  Widget _buildTitleList(int part) {
    final info = _partInfo[part];
    final titles = _ctrl.partTitles[part] ?? [];

    return ListView.builder(
      key: ValueKey('list_$part'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: titles.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          // Sub-header
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _indigoL,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${titles.length} ชุด',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  info?['desc'] ?? '',
                  style: const TextStyle(fontSize: 12, color: _textSec),
                ),
              ],
            ),
          );
        }

        final title = titles[i - 1];
        return _TitleCard(
          title: title,
          index: i - 1,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PartPracticeExamScreen(part: part, title: title),
              ),
            ).then((_) {
              if (mounted) {
                _ctrl.dispose();
                _initCtrl();
                setState(() {});
              }
            });
          },
        );
      },
    );
  }
}

// ── Part Card ─────────────────────────────────────────────────────────────────
class _PartCard extends StatelessWidget {
  final int part;
  final Map<String, dynamic>? info;
  final int titleCount;
  final VoidCallback onTap;

  const _PartCard({
    required this.part,
    required this.info,
    required this.titleCount,
    required this.onTap,
  });

  static const _indigo  = Color(0xFF4F46E5);
  static const _indigoL = Color(0xFFEEF2FF);
  static const _border  = Color(0xFFE5E7EB);
  static const _textPri = Color(0xFF111827);
  static const _textSec = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _indigoL,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(info?['icon'] ?? Icons.assignment_outlined,
                    color: _indigo, size: 20),
              ),
              const Spacer(),
              // Part label
              Text(
                'Part $part',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _indigo,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                info?['name'] ?? 'Part $part',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPri,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _indigoL,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$titleCount ชุด',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _indigo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Title Card ────────────────────────────────────────────────────────────────
class _TitleCard extends StatelessWidget {
  final String title;
  final int index;
  final VoidCallback onTap;

  const _TitleCard(
      {required this.title, required this.index, required this.onTap});

  static const _indigo  = Color(0xFF4F46E5);
  static const _indigoL = Color(0xFFEEF2FF);
  static const _border  = Color(0xFFE5E7EB);
  static const _textPri = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: _indigoL,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _indigo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: _textPri),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFD1D5DB), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
