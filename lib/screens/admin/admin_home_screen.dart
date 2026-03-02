import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminHomeScreen — Responsive Admin Dashboard (Web-first)
// การ์ดหน้าแรกเหลือเฉพาะ feature หลัก
// "เพิ่มข้อสอบ" และ "Import CSV" ถูกยุบเข้าไปอยู่ใน ExamManagement แล้ว
// ─────────────────────────────────────────────────────────────────────────────
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  // breakpoint สำหรับ web sidebar layout
  static const double _sidebarBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _sidebarBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: isWide ? _WideLayout() : _NarrowLayout(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wide layout (≥900px) — Sidebar + Content
// ─────────────────────────────────────────────────────────────────────────────
class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AdminSidebar(),
        Expanded(child: _DashboardBody()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Narrow layout (<900px) — Standard Scaffold with AppBar
// ─────────────────────────────────────────────────────────────────────────────
class _NarrowLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('แผงควบคุม', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [_LogoutButton()],
      ),
      drawer: Drawer(
        child: _AdminSidebar(isDrawer: true),
      ),
      body: _DashboardBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _AdminSidebar extends StatelessWidget {
  final bool isDrawer;
  const _AdminSidebar({this.isDrawer = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: double.infinity,
      color: const Color(0xFF1E3A5F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo / Brand ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VB Admin', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('แผงควบคุม', style: TextStyle(
                    color: Colors.white54, fontSize: 11)),
              ]),
            ]),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 8),

          // ── Nav Items ─────────────────────────────────────────────────────
          _navItem(context, icon: Icons.dashboard_rounded,   label: 'ภาพรวม',          route: '/admin'),
          _navItem(context, icon: Icons.quiz_rounded,        label: 'จัดการข้อสอบ',     route: '/admin/exams', highlight: true),
          _navItem(context, icon: Icons.library_books_rounded, label: 'ชีทสรุป',        route: '/admin/sheets'),
          _navItem(context, icon: Icons.translate_rounded,   label: 'คำศัพท์',          route: '/admin/vocab'),

          const Spacer(),

          // ── Bottom: Logout ─────────────────────────────────────────────────
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _LogoutButton(fullWidth: true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    bool highlight = false,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final isActive = currentRoute == route || (route == '/admin/exams' && currentRoute.startsWith('/admin/exam'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context); // close drawer if open
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: Colors.white.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(children: [
            Icon(icon, color: isActive ? Colors.white : Colors.white60, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
            if (highlight && !isActive) ...[
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Body
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= AdminHomeScreen._sidebarBreakpoint;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 32 : 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ยินดีต้อนรับ 👋',
                style: TextStyle(fontSize: isWide ? 26 : 20,
                    fontWeight: FontWeight.bold, color: const Color(0xFF1E3A5F))),
            const SizedBox(height: 4),
            Text('Admin Panel — TOEIC Practice System',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ])),
          if (!isWide) _LogoutButton(),
        ]),
        const SizedBox(height: 28),

        // ── Stats Row ────────────────────────────────────────────────────────
        _StatsRow(),
        const SizedBox(height: 28),

        // ── Quick Actions ────────────────────────────────────────────────────
        const Text('เมนูหลัก',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F))),
        const SizedBox(height: 14),
        _buildMenuGrid(context, isWide),
      ]),
    );
  }

  Widget _buildMenuGrid(BuildContext context, bool isWide) {
    final items = _menuItems(context);
    final crossCount = isWide ? 3 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isWide ? 1.6 : 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuCard(item: items[i]),
    );
  }

  List<_MenuItem> _menuItems(BuildContext context) => [
    _MenuItem(
      icon: Icons.quiz_rounded,
      title: 'จัดการข้อสอบ',
      subtitle: 'สร้าง แก้ไข เพิ่มข้อ Import CSV',
      gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
      onTap: () => Navigator.pushNamed(context, '/admin/exams'),
    ),
    _MenuItem(
      icon: Icons.library_books_rounded,
      title: 'ชีทสรุป',
      subtitle: 'จัดการเอกสารสรุปบทเรียน',
      gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFEF6C00)]),
      onTap: () => Navigator.pushNamed(context, '/admin/sheets'),
    ),
    _MenuItem(
      icon: Icons.translate_rounded,
      title: 'คำศัพท์',
      subtitle: 'จัดการ Vocabulary ทั้งหมด',
      gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B)]),
      onTap: () => Navigator.pushNamed(context, '/admin/vocab'),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row — ดึงข้อมูลจริงจาก Supabase
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatefulWidget {
  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  final _supabase = Supabase.instance.client;
  int _totalSets = 0;
  int _totalQuestions = 0;
  int _publishedSets = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sets = await _supabase.from('exam_sets').select('is_published');
      final questions = await _supabase.from('practice_test').select('id');
      if (mounted) setState(() {
        _totalSets       = (sets as List).length;
        _publishedSets   = (sets).where((e) => e['is_published'] == true).length;
        _totalQuestions  = (questions as List).length;
        _loading         = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= AdminHomeScreen._sidebarBreakpoint;

    final stats = [
      _StatData('ชุดข้อสอบทั้งหมด', '$_totalSets',
          Icons.folder_rounded, const Color(0xFF1565C0)),
      _StatData('เผยแพร่แล้ว', '$_publishedSets',
          Icons.visibility_rounded, const Color(0xFF2E7D32)),
      _StatData('ข้อสอบทั้งหมด', '$_totalQuestions',
          Icons.quiz_rounded, const Color(0xFFE65100)),
    ];

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Wrap(
            spacing: 14,
            runSpacing: 14,
            children: stats.map((s) => SizedBox(
              width: isWide ? 200 : (MediaQuery.of(context).size.width - 54) / 2,
              child: _StatCard(data: s),
            )).toList(),
          );
  }
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(data.icon, color: data.color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data.value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                  color: data.color)),
          Text(data.label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu Card
// ─────────────────────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String title, subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon, required this.title, required this.subtitle,
    required this.gradient, required this.onTap,
  });
}

class _MenuCard extends StatefulWidget {
  final _MenuItem item;
  const _MenuCard({required this.item});
  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.item.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.item.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: widget.item.gradient.colors.first.withValues(alpha: _hovered ? 0.4 : 0.2),
                  blurRadius: _hovered ? 16 : 8,
                  offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(widget.item.icon, color: Colors.white, size: 30),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.item.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(widget.item.subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout Button — reusable
// ─────────────────────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final bool fullWidth;
  const _LogoutButton({this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    Future<void> logout() async {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }

    if (fullWidth) {
      return TextButton.icon(
        onPressed: logout,
        icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white60),
        label: const Text('ออกจากระบบ',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.centerLeft,
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.logout_rounded),
      tooltip: 'ออกจากระบบ',
      onPressed: logout,
    );
  }
}
