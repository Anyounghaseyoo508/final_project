import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'exam_result_screen.dart'; // import หน้า Result มาใช้

class StudyHistoryScreen extends StatefulWidget {
  const StudyHistoryScreen({super.key});

  @override
  State<StudyHistoryScreen> createState() => _StudyHistoryScreenState();
}

class _StudyHistoryScreenState extends State<StudyHistoryScreen> {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _getHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('exam_submissions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching history: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("ประวัติการสอบ", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final data = snapshot.data ?? [];
          if (data.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) => _buildHistoryCard(data[index]),
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final DateTime createdAt = DateTime.parse(item['created_at']).toLocal();
    final String formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(createdAt);
    
    final int score = item['score'] ?? 0;
    final int total = item['total_questions'] ?? 0;
    final double percent = total > 0 ? (score / total) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          // --- จุดสำคัญ: คลิกแล้วส่งข้อมูลไปหน้า Review ---
          if (item['questions_snapshot'] != null && item['answers'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExamResultScreen(
                  // แปลงข้อมูลจาก Snapshot ใน DB กลับเป็น List/Map
                  questions: List<Map<String, dynamic>>.from(item['questions_snapshot']),
                  userAnswers: Map<int, String>.from(
                    (item['answers'] as Map).map((k, v) => MapEntry(int.parse(k.toString()), v.toString()))
                  ),
                  isHistoryView: true,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("ไม่พบข้อมูลเฉลยสำหรับรายการนี้"))
            );
          }
        },
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: (percent >= 0.7) ? Colors.green.shade50 : (percent >= 0.5 ? Colors.orange.shade50 : Colors.red.shade50),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.assignment_turned_in_rounded,
            color: (percent >= 0.7) ? Colors.green : (percent >= 0.5 ? Colors.orange : Colors.red),
          ),
        ),
        title: Text(
          "Practice Test #${item['test_id']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formattedDate, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            const Text("คลิกเพื่อดูเฉลยละเอียด", style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$score/$total",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
            ),
            const Text("Score", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("ยังไม่มีประวัติการสอบ", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("ลองทำข้อสอบชุดแรกของคุณเลย!", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}