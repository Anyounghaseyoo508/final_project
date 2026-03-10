import 'package:flutter/material.dart';
//import 'package:supabase_flutter/supabase_flutter.dart';
import 'vocab_category_detail_screen.dart';
import 'global_search_screen.dart';

class VocabListScreen extends StatefulWidget {
  final bool showBackButton;
  const VocabListScreen({super.key, this.showBackButton = false});

  @override
  State<VocabListScreen> createState() => _VocabListScreenState();
}

class _VocabListScreenState extends State<VocabListScreen> {
  static const _blue = Color(0xFF1A56DB);
  static const _bg   = Color(0xFFF0F4F8);

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
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ที่ไม่ซ้ำซ้อน: title + subtitle + search รวมกันที่เดียว ──
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 64,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.showBackButton) ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: _blue),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CEFR Standard',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _blue.withOpacity(0.55),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const Text(
                        'English Vocabulary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1729),
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search pill button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const GlobalSearchScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.search_rounded, color: _blue, size: 17),
                        SizedBox(width: 5),
                        Text(
                          'ค้นหา',
                          style: TextStyle(
                            color: _blue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Grid ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VocabCategoryDetailScreen(
                  categoryLevel: cat['level'],
                  categoryTitle: 'ระดับ ${cat['level']} - ${cat['title']}',
                ),
              ),
            ),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(cat['icon'], color: Colors.white, size: 20),
                      ),
                      const Spacer(),
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