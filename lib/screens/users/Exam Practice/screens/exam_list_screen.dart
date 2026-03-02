import 'package:flutter/material.dart';
import '../controller/exam_list_controller.dart';
//import './exam_list_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final _ctrl = ExamListController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("เลือกชุดข้อสอบ TOEIC"),
        backgroundColor: Colors.blueAccent.shade700,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<int>>(
        future: _ctrl.getTestList(), // เรียกผ่าน Controller
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("ยังไม่มีชุดข้อสอบในระบบ"));
          }

          final testIds = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: testIds.length,
            itemBuilder: (context, index) {
              final id = testIds[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    child: Icon(
                      Icons.assignment,
                      color: Colors.blueAccent.shade700,
                    ),
                  ),
                  title: Text(
                    "TOEIC Practice Test #$id",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: const Text("200 Questions • 2 Hours"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // ส่ง testId ไปที่หน้าทำข้อสอบ
                    Navigator.pushNamed(
                      context,
                      '/practice_exam',
                      arguments: id,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
