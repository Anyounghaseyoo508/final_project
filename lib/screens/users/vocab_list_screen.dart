import 'package:flutter/material.dart';
import 'vocab_category_detail_screen.dart';
import 'global_search_screen.dart'; // ไฟล์ใหม่ที่เราจะสร้างเพื่อใช้ค้นหาทั้งหมด

class VocabListScreen extends StatefulWidget {
  const VocabListScreen({super.key});

  @override
  State<VocabListScreen> createState() => _VocabListScreenState();
}

class _VocabListScreenState extends State<VocabListScreen> {
  // ข้อมูลหมวดหมู่ A1-C2 (ใช้โค้ดเดิมที่ปรับ UI แล้ว)
  final List<Map<String, dynamic>> categories = [
    {
      'level': 'A1',
      'title': 'Beginner',
      'subtitle': 'ระดับเริ่มต้น',
      'colors': [Colors.green.shade400, Colors.green.shade700],
      'icon': Icons.child_care,
    },
    {
      'level': 'A2',
      'title': 'Elementary',
      'subtitle': 'ระดับพื้นฐาน',
      'colors': [Colors.blue.shade400, Colors.blue.shade700],
      'icon': Icons.directions_walk,
    },
    {
      'level': 'B1',
      'title': 'Intermediate',
      'subtitle': 'ระดับกลาง',
      'colors': [Colors.orange.shade400, Colors.orange.shade700],
      'icon': Icons.directions_run,
    },
    {
      'level': 'B2',
      'title': 'Upper Inter',
      'subtitle': 'ระดับกลางสูง',
      'colors': [Colors.red.shade400, Colors.red.shade700],
      'icon': Icons.speed,
    },
    {
      'level': 'C1',
      'title': 'Advanced',
      'subtitle': 'ระดับสูง',
      'colors': [Colors.purple.shade400, Colors.purple.shade700],
      'icon': Icons.flight_takeoff,
    },
    {
      'level': 'C2',
      'title': 'Proficiency',
      'subtitle': 'ระดับเชี่ยวชาญ',
      'colors': [Colors.brown.shade400, Colors.brown.shade700],
      'icon': Icons.auto_awesome,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'CEFR Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent.shade700,
        foregroundColor: Colors.white,
        actions: [
          // เพิ่มปุ่ม Search ไว้ที่มุมขวาบนของหน้าหมวดหมู่
          IconButton(
            icon: const Icon(Icons.search, size: 28),
            onPressed: () {
              // เปิดหน้าค้นหาคำศัพท์ทั้งหมดจากทุกระดับ
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GlobalSearchScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              "เลือกตามระดับ หรือกดค้นหาด้านบน",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) =>
                  _buildCategoryCard(context, categories[index]),
            ),
          ),
        ],
      ),
    );
  }

  // ใช้ฟังก์ชัน _buildCategoryCard เดิมที่คุณชอบได้เลยครับ
  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VocabCategoryDetailScreen(
              categoryLevel: cat['level'],
              categoryTitle: "ระดับ ${cat['level']} - ${cat['title']}",
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cat['colors'],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cat['colors'][1].withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                cat['icon'],
                size: 80,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(cat['icon'], color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    cat['level'],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    cat['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    cat['subtitle'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
