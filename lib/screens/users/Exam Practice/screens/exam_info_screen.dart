import 'package:flutter/material.dart';

class ExamInfoScreen extends StatelessWidget {
  const ExamInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เกี่ยวกับข้อสอบ'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A56DB),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF0F4F8),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoCard(
            icon: Icons.source_rounded,
            title: 'แหล่งที่มา',
            content: 'ข้อสอบในแอปนี้นำมาจาก ETS TOEIC Official Practice '
                'ไม่ได้สร้างขึ้นเอง จัดทำเพื่อการศึกษาเท่านั้น',
          ),
          const SizedBox(height: 14),
          _infoCard(
            icon: Icons.copyright_rounded,
            title: 'ลิขสิทธิ์',
            content: 'ลิขสิทธิ์เป็นของ ETS (Educational Testing Service) '
                'ผู้พัฒนาแอปไม่มีส่วนเกี่ยวข้องกับ ETS',
          ),
          const SizedBox(height: 14),
          _infoCard(
            icon: Icons.school_rounded,
            title: 'วัตถุประสงค์',
            content: 'จัดทำเพื่อการศึกษาและฝึกทำข้อสอบ TOEIC '
                'ไม่ได้มีวัตถุประสงค์เชิงพาณิชย์',
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1A56DB), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text(content,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}