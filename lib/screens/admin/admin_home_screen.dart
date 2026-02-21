import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("แผงควบคุมแอดมิน (Admin)"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ยินดีต้อนรับ แอดมิน",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _adminMenuCard(
                    context,
                    title: "จัดการข้อสอบ",
                    icon: Icons.quiz,
                    color: Colors.blue,
                    route: '/admin/exams',
                  ),
                  _adminMenuCard(
                    context,
                    title: "เพิ่มข้อสอบใหม่",
                    icon: Icons.add_to_photos,
                    color: Colors.green,
                    route: '/admin/add',
                  ),
                  _adminMenuCard(
                    context,
                    title: "จัดการชีทสรุป",
                    icon: Icons.library_books,
                    color: Colors.orange,
                    route: '/admin/sheets',
                  ),
                  _adminMenuCard(
                    context,
                    title: "นำเข้าไฟล์ CSV",
                    icon: Icons.file_upload,
                    color: Colors.purple,
                    route: '/admin/import',
                  ),
                  _adminMenuCard(
                    context,
                    title: "จัดการคำศัพท์",
                    icon: Icons.translate,
                    color: Colors.teal,
                    route: '/admin/vocab',
                  ),
                  _adminMenuCard(
                    context,
                    title: "ติดตามผู้ใช้",
                    icon: Icons.analytics,
                    color: Colors.red,
                    route: '/admin/monitoring',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
