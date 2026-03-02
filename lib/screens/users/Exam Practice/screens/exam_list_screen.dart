import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/exam_list_controller.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final _ctrl = ExamListController();

  static const _blue    = Color(0xFF1A56DB);
  static const _blueL   = Color(0xFFEEF3FF);
  static const _bg      = Color(0xFFF0F4F8);
  static const _textSec = Color(0xFF64748B);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'เลือกชุดข้อสอบ TOEIC',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: FutureBuilder<List<ExamSet>>(
        future: _ctrl.getTestList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: _blueL,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.inbox_rounded,
                        size: 48, color: _blue),
                  ),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีชุดข้อสอบในระบบ',
                      style: TextStyle(
                          color: _textSec,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final exams = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final exam = exams[index];
              return _ExamCard(
                exam: exam,
                index: index,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/practice_exam',
                  arguments: exam.testId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ExamSet exam;
  final int index;
  final VoidCallback onTap;

  const _ExamCard(
      {required this.exam, required this.index, required this.onTap});

  static const _border  = Color(0xFFE2E8F0);
  static const _textPri = Color(0xFF0F1729);

  Color get _accent {
    const c = [
      Color(0xFF1A56DB),
      Color(0xFF0891B2),
      Color(0xFF7C3AED),
      Color(0xFF059669),
      Color(0xFFD97706),
    ];
    return c[index % c.length];
  }

  @override
  Widget build(BuildContext context) {
    final a = _accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: a.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Text('#${exam.testId}',
                        style: TextStyle(
                            color: a,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.title,
                          style: const TextStyle(
                              color: _textPri,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _tag(Icons.help_outline_rounded, '200 ข้อ', a),
                        const SizedBox(width: 8),
                        _tag(Icons.timer_outlined, '2 ชั่วโมง', a),
                      ]),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: a.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: a),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label, Color color) => Row(children: [
        Icon(icon, size: 12, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500)),
      ]);
}
