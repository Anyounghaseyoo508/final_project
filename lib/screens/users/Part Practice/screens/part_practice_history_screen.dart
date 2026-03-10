import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controller/part_practice_controller.dart';
import 'part_practice_result_screen.dart';

class PartPracticeHistoryScreen extends StatefulWidget {
  const PartPracticeHistoryScreen({super.key});

  @override
  State<PartPracticeHistoryScreen> createState() =>
      _PartPracticeHistoryScreenState();
}

class _PartPracticeHistoryScreenState
    extends State<PartPracticeHistoryScreen> {
  late final PartPracticeHistoryController _ctrl;

  static const Map<int, String> _partNames = {
    1: 'Photographs',
    2: 'Question-Response',
    3: 'Conversations',
    4: 'Short Talks',
    5: 'Incomplete Sentences',
    6: 'Text Completion',
    7: 'Reading Comprehension',
  };

  @override
  void initState() {
    super.initState();
    _ctrl = PartPracticeHistoryController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Navigate to result screen ───────────────────────────────────────────────

  Future<void> _openResult(PartPracticeSubmission s) async {
    // มี snapshot → เปิดได้เลย
    if (s.questionsSnapshot.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PartPracticeResultScreen(
            result: s.toResult(),
            isHistoryView: true,
          ),
        ),
      );
      return;
    }

    // ไม่มี snapshot (ข้อมูลเก่า) → fallback ดึงจาก DB
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('กำลังโหลดข้อมูลข้อสอบ...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final rows = await Supabase.instance.client
          .from('practice_test')
          .select()
          .eq('part', s.part)
          .eq('title', s.title)
          .order('question_no', ascending: true);

      final questions = List<Map<String, dynamic>>.from(rows);
      if (!mounted) return;

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลข้อสอบในระบบ')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PartPracticeResultScreen(
            result: PartPracticeResult(
              part: s.part,
              title: s.title,
              totalQuestions: s.totalQuestions,
              correctCount: s.correctCount,
              questions: questions,
              userAnswers: s.userAnswersInt,
              submittedAt: s.submittedAt,
            ),
            isHistoryView: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        title: const Text(
          'ประวัติการทำแบบฝึกหัด',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _ctrl.fetchHistory,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: _ctrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ctrl.error != null
              ? _buildError()
              : _ctrl.submissions.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
    );
  }

  // ── States ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('เกิดข้อผิดพลาด: ${_ctrl.error}',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _ctrl.fetchHistory,
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📋', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text(
            'ยังไม่มีประวัติการทำ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'เริ่มทำแบบฝึกหัดแล้วผลจะปรากฏที่นี่',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Main Content ────────────────────────────────────────────────────────────

  Widget _buildContent() {
    final list = _ctrl.filtered;

    return RefreshIndicator(
      onRefresh: _ctrl.fetchHistory,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverToBoxAdapter(child: _buildFilterChips()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '${list.length} รายการ',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          list.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'ไม่มีประวัติสำหรับ Part ${_ctrl.filterPart}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildHistoryCard(list[i]),
                    childCount: list.length,
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ── Summary Card ────────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final avg = _ctrl.overallAverage;
    final color = avg >= 80
        ? Colors.green
        : avg >= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade500, Colors.indigo.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'สถิติรวม',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('${_ctrl.totalAttempts}', 'ครั้งที่ทำ',
                  Icons.assignment_outlined),
              _summaryDivider(),
              _summaryItem('${avg.toStringAsFixed(1)}%', 'เฉลี่ย',
                  Icons.trending_up,
                  highlight: true, highlightColor: color),
              _summaryDivider(),
              Column(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white60, size: 18),
                  const SizedBox(height: 6),
                  Text(
                    '${_ctrl.totalCorrect}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text('ข้อที่ทำถูกทั้งหมด',
                      style:
                          TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(
                    '${_ctrl.totalQuestions}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text('ข้อที่เคยทำทั้งหมด',
                      style:
                          TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ],
          ),
          if (_ctrl.mostPracticedPart != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '⭐ Part ที่ทำบ่อยสุด: Part ${_ctrl.mostPracticedPart}'
                ' — ${_partNames[_ctrl.mostPracticedPart] ?? ''}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, IconData icon,
      {bool highlight = false, Color? highlightColor}) {
    final color = highlight ? (highlightColor ?? Colors.white) : Colors.white;
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _summaryDivider() => Container(
        height: 40,
        width: 1,
        color: Colors.white.withOpacity(0.2),
      );

  // ── Filter Chips ────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final partsInHistory =
        _ctrl.submissions.map((s) => s.part).toSet().toList()..sort();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(null, 'ทั้งหมด'),
          ...partsInHistory.map((p) => _chip(p, 'Part $p')),
        ],
      ),
    );
  }

  Widget _chip(int? part, String label) {
    final isSelected = _ctrl.filterPart == part;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => _ctrl.setFilter(part),
        selectedColor: Colors.indigo.shade100,
        checkmarkColor: Colors.indigo,
        labelStyle: TextStyle(
          color: isSelected ? Colors.indigo : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        side: BorderSide(
          color: isSelected ? Colors.indigo : Colors.grey.shade300,
        ),
      ),
    );
  }

  // ── History Card ────────────────────────────────────────────────────────────

  Widget _buildHistoryCard(PartPracticeSubmission s) {
    final color = s.gradeColor();
    final partName = _partNames[s.part] ?? 'Part ${s.part}';

    return GestureDetector(
      onTap: () => _openResult(s),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left score panel ──
              Container(
                width: 72,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.gradeEmoji,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      '${s.percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Part badge + name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Part ${s.part}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              partName,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // ชื่อชุด + วันที่ (รวมบรรทัดเดียว ประหยัดพื้นที่)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(s.submittedAt),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.percentage / 100,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Stats + hint
                      Row(
                        children: [
                          _miniStat(
                              '✅ ${s.correctCount}', Colors.green.shade700),
                          const SizedBox(width: 10),
                          _miniStat(
                              '❌ ${s.totalQuestions - s.correctCount}',
                              Colors.red.shade400),
                          const SizedBox(width: 10),
                          _miniStat(
                              '📋 ${s.totalQuestions}', Colors.grey.shade600),
                          const Spacer(),
                          Text(
                            'ดูเฉลย →',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.indigo.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String text, Color color) => Text(
        text,
        style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w600),
      );

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'เมื่อกี้';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays == 1) return 'เมื่อวาน';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${dt.day}/${dt.month}/${dt.year + 543}';
  }
}