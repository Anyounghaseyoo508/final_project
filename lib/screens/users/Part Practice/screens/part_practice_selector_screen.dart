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
  static const _bg      = Color(0xFFF4F6FB);
  static const _surface = Color(0xFFFFFFFF);
  static const _indigo  = Color(0xFF4F46E5);
  static const _border  = Color(0xFFE5E7EB);
  static const _textPri = Color(0xFF111827);
  static const _textSec = Color(0xFF6B7280);

  // สีประจำ Part แต่ละพาร์ท
  static const Map<int, Color> _partColors = {
    1: Color(0xFF0EA5E9), // sky blue
    2: Color(0xFF8B5CF6), // violet
    3: Color(0xFF10B981), // emerald
    4: Color(0xFFF59E0B), // amber
    5: Color(0xFFEF4444), // red
    6: Color(0xFFEC4899), // pink
    7: Color(0xFF6366F1), // indigo
  };

  static const Map<int, Map<String, dynamic>> _partInfo = {
    1: {
      'icon': Icons.photo_camera_outlined,
      'name': 'Photographs',
      'desc': 'เลือกประโยคที่ตรงกับรูปภาพ',
      'tag': 'Listening',
    },
    2: {
      'icon': Icons.headset_mic_outlined,
      'name': 'Question-Response',
      'desc': 'เลือกคำตอบที่เหมาะสมที่สุด',
      'tag': 'Listening',
    },
    3: {
      'icon': Icons.people_outline_rounded,
      'name': 'Conversations',
      'desc': 'ฟังบทสนทนาแล้วตอบคำถาม',
      'tag': 'Listening',
    },
    4: {
      'icon': Icons.spatial_audio_off_rounded,
      'name': 'Short Talks',
      'desc': 'ฟังการพูดแล้วตอบคำถาม',
      'tag': 'Listening',
    },
    5: {
      'icon': Icons.text_fields_rounded,
      'name': 'Incomplete Sentences',
      'desc': 'เติมคำในช่องว่าง',
      'tag': 'Reading',
    },
    6: {
      'icon': Icons.article_rounded,
      'name': 'Text Completion',
      'desc': 'เติมคำในบทความ',
      'tag': 'Reading',
    },
    7: {
      'icon': Icons.auto_stories_rounded,
      'name': 'Reading Comprehension',
      'desc': 'อ่านบทความแล้วตอบคำถาม',
      'tag': 'Reading',
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
                          size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Part $_selectedPart — ${_partInfo[_selectedPart]?['name'] ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
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
    final listening = _ctrl.availableParts.where((p) => p <= 4).toList();
    final reading   = _ctrl.availableParts.where((p) => p > 4).toList();

    return ListView(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if (listening.isNotEmpty) ...[
          _sectionHeader('🎧 Listening', listening.length),
          const SizedBox(height: 12),
          _partRow(listening),
          const SizedBox(height: 24),
        ],
        if (reading.isNotEmpty) ...[
          _sectionHeader('📖 Reading', reading.length),
          const SizedBox(height: 12),
          _partRow(reading),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Row(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _textPri)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count Part',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _textSec)),
      ),
    ]);
  }

  Widget _partRow(List<int> parts) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.0,
      ),
      itemCount: parts.length,
      itemBuilder: (context, i) {
        final part = parts[i];
        final info = _partInfo[part];
        final color = _partColors[part] ?? _indigo;
        final titleCount = _ctrl.partTitles[part]?.length ?? 0;
        return _PartCard(
          part: part,
          info: info,
          color: color,
          titleCount: titleCount,
          onTap: () => setState(() => _selectedPart = part),
        );
      },
    );
  }

  // ── Title List ────────────────────────────────────────────────────────────
  Widget _buildTitleList(int part) {
    final info   = _partInfo[part];
    final titles = _ctrl.partTitles[part] ?? [];
    final color  = _partColors[part] ?? _indigo;

    return ListView.builder(
      key: ValueKey('list_$part'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: titles.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${titles.length} ชุด',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
              const SizedBox(width: 8),
              Text(info?['desc'] ?? '',
                  style:
                      const TextStyle(fontSize: 12, color: _textSec)),
            ]),
          );
        }

        final title = titles[i - 1];
        final best = _ctrl.getBestScore(part, title);
        return _TitleCard(
          title: title,
          index: i - 1,
          color: color,
          bestScore: best,
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
  final Color color;
  final int titleCount;
  final VoidCallback onTap;

  const _PartCard({
    required this.part,
    required this.info,
    required this.color,
    required this.titleCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgLight = color.withOpacity(0.08);
    final bgMid   = color.withOpacity(0.15);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Stack(children: [
            // decorative circle top-right
            Positioned(
              right: -18, top: -18,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: bgMid,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: bgLight,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                        info?['icon'] ?? Icons.assignment_outlined,
                        color: color, size: 22),
                  ),
                  const Spacer(),
                  Text('Part $part',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(info?['name'] ?? 'Part $part',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bgMid,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$titleCount ชุด',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Title Card ────────────────────────────────────────────────────────────────
class _TitleCard extends StatelessWidget {
  final String title;
  final int index;
  final Color color;
  final double? bestScore;
  final VoidCallback onTap;

  const _TitleCard({
    required this.title,
    required this.index,
    required this.color,
    required this.bestScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBest = bestScore != null;
    final scoreColor = bestScore == null
        ? Colors.grey
        : bestScore! >= 80
            ? Colors.green
            : bestScore! >= 50
                ? Colors.orange
                : Colors.red;

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
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              // index badge
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF111827))),
                    if (hasBest) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.emoji_events_rounded,
                            size: 12, color: scoreColor),
                        const SizedBox(width: 4),
                        Text(
                          'สูงสุด ${bestScore!.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 11,
                              color: scoreColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text('ยังไม่เคยทำ',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF))),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: color, size: 18),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}