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
  static const _textPri = Color(0xFF111827);
  static const _textSec = Color(0xFF6B7280);

  static const Map<int, Color> _partColors = {
    1: Color(0xFF0EA5E9),
    2: Color(0xFF8B5CF6),
    3: Color(0xFF10B981),
    4: Color(0xFFF59E0B),
    5: Color(0xFFEF4444),
    6: Color(0xFFEC4899),
    7: Color(0xFF6366F1),
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
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _selectedPart == null
              ? () => Navigator.pop(context)
              : () => setState(() => _selectedPart = null),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectedPart == null
              ? const Text(
                  'แบบฝึกหัดรายพาร์ท',
                  key: ValueKey('main'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                )
              : Align(
                  key: const ValueKey('detail'),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Part $_selectedPart — ${_partInfo[_selectedPart]?['name'] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
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

    // responsive: ถ้าจอกว้าง (tablet/desktop) ใช้ 4 columns, มือถือใช้ 2
    final screenW = MediaQuery.of(context).size.width;
    final crossCount = screenW >= 600 ? 4 : 2;
    return ListView(
      key: const ValueKey('grid'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
      children: [
        if (listening.isNotEmpty) ...[
          _sectionHeader('🎧 Listening', listening.length),
          const SizedBox(height: 10),
          _partGrid(listening, crossCount, 1.0),
          const SizedBox(height: 20),
        ],
        if (reading.isNotEmpty) ...[
          _sectionHeader('📖 Reading', reading.length),
          const SizedBox(height: 10),
          _partGrid(reading, crossCount, 1.0),
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

  Widget _partGrid(List<int> parts, int crossCount, double aspectRatio) {
    // ใช้ LayoutBuilder + Row แทน GridView เพื่อให้ card สูงตาม content จริง
    // ไม่มี fixed aspect ratio → ไม่มีทาง overflow
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
        final rows = <Widget>[];
        for (int i = 0; i < parts.length; i += crossCount) {
          final rowParts = parts.sublist(i, (i + crossCount).clamp(0, parts.length));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int j = 0; j < rowParts.length; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  SizedBox(
                    width: cardWidth,
                    child: _PartCard(
                      part: rowParts[j],
                      info: _partInfo[rowParts[j]],
                      color: _partColors[rowParts[j]] ?? _indigo,
                      titleCount: _ctrl.partTitles[rowParts[j]]?.length ?? 0,
                      onTap: () => setState(() => _selectedPart = rowParts[j]),
                    ),
                  ),
                ],
                // ถ้า row ไม่เต็ม ให้ใส่ spacer เพื่อ align ซ้าย
                if (rowParts.length < crossCount)
                  Expanded(child: SizedBox()),
              ],
            ),
          );
          if (i + crossCount < parts.length) rows.add(SizedBox(height: spacing));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
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
              Flexible(
                child: Text(info?['desc'] ?? '',
                    style: const TextStyle(fontSize: 12, color: _textSec),
                    overflow: TextOverflow.ellipsis),
              ),
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PartPracticeExamScreen(part: part, title: title),
              ),
            );
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
    // icon size responsive ตาม screen width
    final screenW = MediaQuery.of(context).size.width;
    // breakpoints: จอเล็ก < 360 | มือถือ < 600 | tablet < 900 | desktop ≥ 900
    final double iconBoxSize;
    final double iconSize;
    final double nameFontSize;
    if (screenW < 360) {
      iconBoxSize  = 52; iconSize = 30; nameFontSize = 11;
    } else if (screenW < 600) {
      iconBoxSize  = 62; iconSize = 36; nameFontSize = 12;
    } else if (screenW < 900) {
      // iPad / tablet
      iconBoxSize  = 80; iconSize = 48; nameFontSize = 14;
    } else {
      // desktop
      iconBoxSize  = 88; iconSize = 52; nameFontSize = 15;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                    info?['icon'] ?? Icons.assignment_outlined,
                    color: color, size: iconSize),
              ),
              const SizedBox(height: 8),
              Text('Part $part',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(
                info?['name'] ?? 'Part $part',
                style: TextStyle(
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
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
            ? const Color(0xFF16A34A)
            : bestScore! >= 50
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(children: [
              // index badge
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: color)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 3),
                    if (hasBest)
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
                      ])
                    else
                      const Text('ยังไม่เคยทำ',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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