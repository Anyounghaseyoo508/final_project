import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'exam_result_screen.dart';
import '../controller/study_history_controller.dart';

class StudyHistoryScreen extends StatefulWidget {
  const StudyHistoryScreen({super.key});

  @override
  State<StudyHistoryScreen> createState() => _StudyHistoryScreenState();
}

class _StudyHistoryScreenState extends State<StudyHistoryScreen> {
  // ── Controller ────────────────────────────────────────────────
  final _ctrl = StudyHistoryController();

  // ── Filter State ──────────────────────────────────────────────
  DateTime? _filterDate; // null = แสดงทั้งหมด

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── เปิด Date Picker แล้วอัป state ──────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'เลือกวันที่ต้องการดูประวัติ',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _filterDate = picked);
    }
  }

  // ── ล้าง filter ───────────────────────────────────────────────
  void _clearFilter() => setState(() => _filterDate = null);

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isFiltered = _filterDate != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "ประวัติการสอบ",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // ── ถ้ากำลัง filter อยู่ → แสดงปุ่ม clear ด้วย ──────
          if (isFiltered)
            IconButton(
              tooltip: 'ล้างตัวกรอง',
              icon: const Icon(Icons.filter_alt_off_rounded, color: Colors.red),
              onPressed: _clearFilter,
            ),
          // ── ปุ่มเปิด Date Picker ─────────────────────────────
          IconButton(
            tooltip: 'กรองตามวันที่',
            icon: Badge(
              isLabelVisible: isFiltered,
              smallSize: 8,
              backgroundColor: Colors.indigo.shade700,
              child: Icon(
                Icons.calendar_month_rounded,
                color: isFiltered ? Colors.indigo.shade700 : Colors.black,
              ),
            ),
            onPressed: _pickDate,
          ),
        ],
      ),

      // ── แสดง chip วันที่ที่เลือกอยู่ ─────────────────────────
      body: Column(
        children: [
          if (isFiltered)
            Container(
              width: double.infinity,
              color: Colors.indigo.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 16, color: Colors.indigo.shade700),
                  const SizedBox(width: 6),
                  Text(
                    "กรองวันที่: ${DateFormat('dd MMM yyyy').format(_filterDate!)}",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearFilter,
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.indigo.shade400),
                  ),
                ],
              ),
            ),

          // ── List ───────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              // key เปลี่ยนตาม filterDate → rebuild FutureBuilder ทุกครั้งที่ filter เปลี่ยน
              key: ValueKey(_filterDate),
              future: _ctrl.getHistory(filterDate: _filterDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final data = snapshot.data ?? [];
                if (data.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  itemBuilder: (context, index) =>
                      _buildHistoryCard(data[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final DateTime createdAt = DateTime.parse(item['created_at']).toLocal();
    final String formattedDate =
        DateFormat('dd MMM yyyy, HH:mm').format(createdAt);

    final int score = item['score'] ?? 0;
    final int total = item['total_questions'] ?? 0;
    final double percent = total > 0 ? (score / total) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => _onTapHistoryCard(item),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: (percent >= 0.7)
                ? Colors.green.shade50
                : (percent >= 0.5
                    ? Colors.orange.shade50
                    : Colors.red.shade50),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.assignment_turned_in_rounded,
            color: (percent >= 0.7)
                ? Colors.green
                : (percent >= 0.5 ? Colors.orange : Colors.red),
          ),
        ),
        title: Text(
          () {
            try {
              final snapshot = item['questions_snapshot'];
              if (snapshot != null && snapshot is List && snapshot.isNotEmpty) {
                return snapshot.first['title']?.toString() ??
                    "Practice Test #${item['test_id']}";
              }
            } catch (_) {}
            return "Practice Test #${item['test_id']}";
          }(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formattedDate, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            const Text(
              "คลิกเพื่อดูเฉลยละเอียด",
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$score/$total",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            const Text(
              "Score",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapHistoryCard(Map<String, dynamic> item) {
    final questions = _ctrl.getQuestionsFromSnapshot(item);

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ไม่พบข้อมูลข้อสอบ")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamResultScreen(
          questions:         questions,
          userAnswers:       item['answers'] ?? {},
          isHistoryView:     true,
          durationSeconds:   item['duration_seconds'] ?? 0,
          // ใช้คะแนนที่ save ไว้ใน DB เลย ไม่ต้องคิดใหม่
          precomputedLRaw:   item['listening_raw'],
          precomputedRRaw:   item['reading_raw'],
          precomputedLToeic: item['l_toeic'],
          precomputedRToeic: item['r_toeic'],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filterDate != null
                ? Icons.event_busy_rounded  // ไม่มีข้อมูลวันนั้น
                : Icons.history_edu_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _filterDate != null
                ? "ไม่มีประวัติในวันที่\n${DateFormat('dd MMM yyyy').format(_filterDate!)}"
                : "ยังไม่มีประวัติการสอบ",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterDate != null
                ? "ลองเลือกวันอื่น หรือกด X เพื่อดูทั้งหมด"
                : "ลองทำข้อสอบชุดแรกของคุณเลย!",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}