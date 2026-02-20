import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vocab_category_detail_screen.dart';
import 'global_search_screen.dart';

class VocabListScreen extends StatefulWidget {
  const VocabListScreen({super.key});

  @override
  State<VocabListScreen> createState() => _VocabListScreenState();
}

class _VocabListScreenState extends State<VocabListScreen> {
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

  Future<void> getCategoryStats() async {
    // ดึงข้อมูลจำนวนคำแยกตาม CEFR
    final response = await Supabase.instance.client
        .from('vocabularies')
        .select('CEFR');

    // ใช้ Map ในการนับจำนวน
    Map<String, int> stats = {};
    for (var item in response) {
      String level = item['CEFR'] ?? 'Unknown';
      stats[level] = (stats[level] ?? 0) + 1;
    }

    print(stats); // จะได้ผลลัพธ์เช่น {A1: 500, A2: 800, ...}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        title: const Text(
          'English Vocabulary',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        centerTitle: false, // ปรับให้ชิดซ้ายดูทันสมัยกว่า
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          // ปุ่มค้นหาแบบวงกลม
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.blueAccent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GlobalSearchScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        // ใช้ CustomScrollView เพื่อให้เลื่อนดูได้ลื่นไหลขึ้น
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "CEFR Standard",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueAccent.shade700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "เลือกตามระดับความรู้",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildCategoryCard(context, categories[index]),
                childCount: categories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (cat['colors'][1] as Color).withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cat['colors'],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Icon พื้นหลัง (ปรับให้ดูจมลงไปในพื้นผิว)
                  Positioned(
                    right: -15,
                    bottom: -15,
                    child: Icon(
                      cat['icon'],
                      size: 90,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge วงกลมเล็กๆ
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat['icon'], color: Colors.white, size: 20),
                      ),
                      const Spacer(),
                      // ตัวอักษรระดับใหญ่ๆ
                      Text(
                        cat['level'],
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        cat['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat['subtitle'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
