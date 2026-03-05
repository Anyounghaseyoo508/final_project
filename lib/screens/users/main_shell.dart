import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './dashboard_screen.dart';
import './Exam Practice/screens/exam_list_screen.dart';
import './Part Practice/screens/part_practice_selector_screen.dart';
import './Vocabulary Learning/vocab_list_screen.dart';
import '../users/games/games_menu_screen.dart';
import './profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 2;
  static const _accent = Color(0xFF1A56DB);

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _ExamHubScreen(), // 0
      const VocabListScreen(), // 1
      UserDashboardScreen(onGamesTap: () => setState(() => _idx = 3)), // 2
      const GamesMenuScreen(), // 3 ← เพิ่ม
      const ProfileScreen(), // 4 ← เพิ่ม (ถ้ามี)
    ];
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: IndexedStack(index: _idx, children: pages),
      floatingActionButton: _HomeFAB(
        isActive: _idx == 2,
        accent: _accent,
        onTap: () => setState(() => _idx = 2),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _NavBar(
        currentIndex: _idx,
        accent: _accent,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ── Home FAB ──────────────────────────────────────────────────────────────────
class _HomeFAB extends StatelessWidget {
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  const _HomeFAB(
      {required this.isActive, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isActive ? 0.35 : 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          // ── เอาขอบสีน้ำเงินออกแล้วครับ ───────────────────────
          border: isActive
              ? null // ตอนที่ถูกเลือกจะไม่มีขอบ
              : Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5), // ขอบเทาตอนไม่ได้เลือก
        ),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isActive ? 1.0 : 0.45,
            child: Image.asset(
              'assets/icons/icons8-home-100.png', // อย่าลืมแก้ให้ตรงกับชื่อไฟล์ของคุณนะครับ
              width: 28,
              height: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom Nav Bar ────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final int currentIndex;
  final Color accent;
  final ValueChanged<int> onTap;

  const _NavBar({
    required this.currentIndex,
    required this.accent,
    required this.onTap,
  });

  static const _tabs = [
    _Tab('assets/icons/icons8-exam-100.png', 'ข้อสอบ', 0),
    _Tab('assets/icons/icons8-vocabulary.png', 'คลังคำ', 1),
    _Tab('assets/icons/icons8-game-controller-100-2.png', 'เกม', 3),
    _Tab('assets/icons/icons8-profile-100.png', 'โปรไฟล์', 4),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            ..._tabs.take(2).map((tab) => _buildItem(tab)),
            const Expanded(child: SizedBox()),
            ..._tabs.skip(2).map((tab) => _buildItem(tab)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_Tab tab) {
    final sel = currentIndex == tab.pageIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(tab.pageIndex),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? accent.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              // ── แก้ไขส่วนนี้เพื่อโชว์สีรูปต้นฉบับ ───────────────────────
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: sel
                    ? 1.0
                    : 0.45, // ถ้าเลือกจะสีสด 100% ถ้าไม่ได้เลือกจะจางลง
                child: Image.asset(
                  tab.imagePath,
                  width: 24,
                  height: 24,
                  // เอา color และ colorBlendMode ออกเพื่อไม่ให้โดนทับสี
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                color: sel ? accent : const Color(0xFFB0B8C9),
              ),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final String imagePath; // ← เพิ่ม
  final String label;
  final int pageIndex;
  const _Tab(this.imagePath, this.label, this.pageIndex);
}

// ── Exam Hub ──────────────────────────────────────────────────────────────────
class _ExamHubScreen extends StatelessWidget {
  const _ExamHubScreen();

  static const _bg = Color(0xFFF0F4F8);
  static const _blue = Color(0xFF1A56DB);
  static const _textSec = Color(0xFF64748B);

  static const _modes = [
    _ExamMode(
      imagePath: 'assets/images/FullmockTest.jpg',
      icon: Icons.assignment_rounded, // fallback ถ้าโหลดรูปไม่ได้
      title: 'Full Mock Test',
      desc: 'ทำข้อสอบ TOEIC เต็มรูปแบบ 200 ข้อ',
      accent: Color(0xFF1A56DB),
      route: _ExamRoute.fullTest,
    ),
    _ExamMode(
      // ── ใส่ path รูปของคุณตรงนี้ ──────────────────────────────────
      imagePath: 'assets/images/PartPracticeTest.png',
      icon: Icons.tune_rounded, // fallback ถ้าโหลดรูปไม่ได้
      title: 'Part Practice',
      desc: 'ฝึกทีละ Part เจาะจุดอ่อน',
      accent: Color(0xFF7C3AED),
      route: _ExamRoute.partPractice,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: _blue,
        elevation: 0,
        title: const Text(
          'Exam Practice',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const Text(
            'เลือกโหมดการทำข้อสอบ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textSec,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          ..._modes.map((mode) => _ModeCard(
                mode: mode,
                onTap: () => _navigate(context, mode.route),
              )),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, _ExamRoute route) {
    switch (route) {
      case _ExamRoute.fullTest:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ExamListScreen()));
        break;
      case _ExamRoute.partPractice:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PartPracticeSelectorScreen()));
        break;
    }
  }
}

enum _ExamRoute { fullTest, partPractice }

class _ExamMode {
  final String imagePath; // path รูปใน assets
  final IconData icon; // fallback icon ถ้าโหลดรูปไม่ได้
  final String title;
  final String desc;
  final Color accent;
  final _ExamRoute route;

  const _ExamMode({
    required this.imagePath,
    required this.icon,
    required this.title,
    required this.desc,
    required this.accent,
    required this.route,
  });
}

class _ModeCard extends StatelessWidget {
  final _ExamMode mode;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.onTap});

  static const _border = Color(0xFFE2E8F0);
  static const _textPri = Color(0xFF0F1729);
  static const _textSec = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // ── รูป asset หรือ fallback icon ───────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    mode.imagePath,
                    width: 130,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 160,
                      height: 110,
                      decoration: BoxDecoration(
                        color: mode.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(mode.icon, color: mode.accent, size: 40),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.title,
                          style: const TextStyle(
                              color: _textPri,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(mode.desc,
                          style:
                              const TextStyle(color: _textSec, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: mode.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: mode.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}