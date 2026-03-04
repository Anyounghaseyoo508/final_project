import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Vocabulary Learning/vocab_list_screen.dart';
import 'learning_resources_screen.dart';
import '../users/Exam Practice/screens/study_history_screen.dart';
import '../users/Exam Practice/screens/exam_list_screen.dart';
import 'Part Practice/screens/part_practice_selector_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _P {
  static const bg         = Color(0xFFF8F9FC);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F4F8);
  static const border     = Color(0xFFEAECF2);

  static const blue       = Color(0xFF1A56DB);
  static const blueLight  = Color(0xFFEEF3FF);
  static const blueMid    = Color(0xFF3B72F6);

  static const green      = Color(0xFF16A34A);
  static const greenBg    = Color(0xFFECFDF5);
  static const red        = Color(0xFFDC2626);
  static const redBg      = Color(0xFFFEF2F2);
  static const orange     = Color(0xFFEA7317);
  static const orangeBg   = Color(0xFFFFF7ED);
  static const teal       = Color(0xFF0891B2);
  static const tealBg     = Color(0xFFECFEFF);
  static const purple     = Color(0xFF7C3AED);
  static const purpleBg   = Color(0xFFF5F3FF);
  static const amber      = Color(0xFFD97706);
  static const amberBg    = Color(0xFFFFFBEB);

  static const textPri    = Color(0xFF0F1729);
  static const textSec    = Color(0xFF64748B);
  static const textMute   = Color(0xFFADB5C7);
}

class UserDashboardScreen extends StatefulWidget {
  final VoidCallback? onGamesTap;
  const UserDashboardScreen({super.key, this.onGamesTap});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  bool   _isLoading    = true;
  String _userName     = 'User';
  int    _totalExams   = 0;
  int    _lastScore    = 0;
  int    _bestScore    = 0;
  String _lastLevel    = '';
  int    _bookmarkCount= 0;
  String _lastTitle    = '';
  String _lastDate     = '';
  int    _worstScore   = 0;
  String _bestLevel    = '';
  String _worstLevel   = '';
  String _bestTitle    = '';
  String _worstTitle   = '';


  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) { setState(() => _isLoading = false); return; }

    try {
      final futures = await Future.wait<dynamic>([
        _supabase.from('users').select('display_name').eq('id', user.id).maybeSingle(),
        _supabase.from('exam_submissions')
            .select('total_score, l_toeic, r_toeic, cefr_level, created_at, test_id')
            .eq('user_id', user.id)
            .not('total_score', 'is', null)
            .order('created_at', ascending: false),
        _supabase.from('bookmarks').select('id').eq('user_id', user.id),
      ]);

      // ดึง title จาก practice_test ตาม test_id ที่เคยสอบ
      final examList = futures[1] as List;
      final testIds  = examList.map((e) => e['test_id']).toSet().toList();
      List testRows  = [];
      if (testIds.isNotEmpty) {
        testRows = await _supabase
            .from('practice_test')
            .select('test_id, title')
            .inFilter('test_id', testIds);
      }
      final profile   = futures[0] as Map?;
      final exams     = examList;
      final bookmarks = futures[2] as List;

      // สร้าง map test_id -> title (สำหรับ lastTitle เท่านั้น)
      final Map<int, String> testTitles = {};
      for (final r in testRows) {
        final id = (r['test_id'] as num?)?.toInt();
        final t  = r['title']?.toString() ?? '';
        if (id != null && t.isNotEmpty && !testTitles.containsKey(id)) {
          testTitles[id] = t;
        }
      }

      int best = 0;
      String bestLevel  = '';
      String bestTitle  = '';
      int worst = 999999;
      String worstLevel = '';
      String worstTitle = '';

      for (final e in exams) {
        final s   = (e['total_score'] as num?)?.toInt() ?? 0;
        final tid = (e['test_id'] as num?)?.toInt() ?? 0;
        final lv  = (e['cefr_level'] as Object? ?? '').toString();
        final ttl = (testTitles[tid] ?? '').toString();
        if (s > best)  { best  = s; bestLevel  = lv; bestTitle  = ttl; }
        if (s < worst) { worst = s; worstLevel = lv; worstTitle = ttl; }
      }
      if (worst == 999999) worst = 0;

      final lastTestId = exams.isNotEmpty ? (exams[0]['test_id'] as num?)?.toInt() ?? 0 : 0;
      final String lastTitle = testTitles[lastTestId] ?? '';
      final String lastDate  = exams.isNotEmpty ? _fmtDate(exams[0]['created_at']?.toString() ?? '') : '';
      final lastScore = exams.isNotEmpty ? (exams[0]['total_score'] as num?)?.toInt() ?? 0 : 0;
      final lastLevel = exams.isNotEmpty ? ((exams[0]['cefr_level'] as Object?) ?? '').toString() : '';

      final name = profile?['display_name']?.toString().trim() ?? '';
      setState(() {
        _userName      = name.isNotEmpty ? name.split(' ').first : 'User';
        _totalExams    = exams.length;
        _lastScore     = lastScore;
        _bestScore     = best;
        _lastLevel     = lastLevel;
        _bookmarkCount = bookmarks.length;
        _lastTitle     = lastTitle.toString();
        _lastDate      = lastDate.toString();
        _worstScore    = worst;
        _bestLevel     = bestLevel.toString();
        _worstLevel    = worstLevel.toString();
        _bestTitle     = bestTitle.toString();
        _worstTitle    = worstTitle.toString();
        _isLoading     = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      debugPrint('_loadStats error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _P.bg,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: _P.blue,
        backgroundColor: _P.surface,
        displacement: 80,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeader(
                userName: _userName,
                bookmarkCount: _bookmarkCount,
                statusBarHeight: MediaQuery.of(context).padding.top,
                onBookmarkTap: () =>
                    Navigator.pushNamed(context, '/bookmarks')
                        .then((_) => _loadStats()),
                onNotificationsTap: () =>
                    Navigator.pushNamed(context, '/notifications'),
                onProfileTap: () =>
                    Navigator.pushNamed(context, '/profile'),
                onStatisticsTap: () =>
                    Navigator.pushNamed(context, '/statistics'),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: _P.blue, strokeWidth: 2)),
              )
            else
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero ───────────────────────────────────────
                        _totalExams > 0
                            ? _heroScoreCard()
                            : _noExamBanner(context),

                        // ── Quick Actions ──────────────────────────────
                        const SizedBox(height: 28),
                        _label('เมนูลัด'),
                        const SizedBox(height: 14),
                        _quickActions(context),

                        // ── Learning Resources ─────────────────────────
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _label('แหล่งเรียนรู้', sub: 'แนะนำโดยผู้ดูแล'),
                            GestureDetector(
                              onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) =>
                                  const LearningResourcesScreen())),
                              child: const Row(children: [
                                Text('ดูทั้งหมด',
                                    style: TextStyle(
                                        color: _P.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 11, color: _P.blue),
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _DashboardResourcesRow(),

                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Hero Score Card ──────────────────────────────────────────────────────
  Widget _heroScoreCard() {
    final double lastPct  = _lastScore  / 990.0;
    final double bestPct  = _bestScore  / 990.0;
    final double worstPct = _worstScore / 990.0;

    return Container(
      decoration: BoxDecoration(
        color: _P.blue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: _P.blue.withOpacity(0.28),
            blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(children: [

        // ══ ส่วนบน: สูงสุด / ต่ำสุด ══════════════════════════════════════
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Row(children: [

            // สูงสุด
            Expanded(child: _statMiniPanel(
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFFFD700),
              label: 'สูงสุด',
              score: _bestScore,
              pct: bestPct,
              barColor: Colors.white,
              cefrLevel: _bestLevel,
              title: _bestTitle,
            )),

            // Vertical divider
            Container(
              width: 1, height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withOpacity(0.12),
            ),

            // ต่ำสุด
            Expanded(child: _statMiniPanel(
              icon: Icons.trending_down_rounded,
              iconColor: const Color(0xFFFCA5A5),
              label: 'ต่ำสุด',
              score: _worstScore,
              pct: worstPct,
              barColor: const Color(0xFFFCA5A5),
              cefrLevel: _worstLevel,
              title: _worstTitle,
            )),
          ]),
        ),

        // ── Divider ──────────────────────────────────────────────────────
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: Colors.white.withOpacity(0.12),
        ),

        // ══ ส่วนล่าง: คะแนนล่าสุด ════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

            // ซ้าย: ข้อมูลล่าสุด
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ครั้งล่าสุด',
                  style: TextStyle(color: Colors.white54, fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_lastScore.toString(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.0, letterSpacing: -1)),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4, left: 4),
                  child: Text('/ 990',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                if (_lastLevel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(_lastLevel,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_lastDate.isNotEmpty)
                  Text(_lastDate,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
              ]),
              if (_lastTitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(_lastTitle,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ])),

            // ขวา: วงกลม % + จำนวนครั้ง
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60, height: 60,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 60, height: 60,
                        child: CircularProgressIndicator(
                            value: 1, strokeWidth: 6,
                            color: Colors.white.withOpacity(0.12))),
                    SizedBox(width: 60, height: 60,
                        child: CircularProgressIndicator(
                            value: lastPct, strokeWidth: 6,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            strokeCap: StrokeCap.round)),
                    Text('${(lastPct * 100).round()}%',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.assignment_rounded,
                        size: 10, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text('$_totalExams ครั้ง',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ),
          ]),
        ),

      ]),
    );
  }

  Widget _statMiniPanel({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int score,
    required double pct,
    required Color barColor,
    required String cefrLevel,
    required String title,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // ซ้าย: label + score + cefr + title
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(score.toString(),
                style: const TextStyle(
                    color: Colors.white, fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.0, letterSpacing: -1)),
            const Padding(
              padding: EdgeInsets.only(bottom: 4, left: 4),
              child: Text('/ 990',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ]),
        ),
        if (cefrLevel.isNotEmpty) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(cefrLevel,
                style: TextStyle(
                    color: barColor == Colors.white ? Colors.white : barColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
        if (title.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(title,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10),
              overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ])),

      const SizedBox(width: 12),

      // ขวา: pie chart
      SizedBox(
        width: 60, height: 60,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 60, height: 60,
              child: CircularProgressIndicator(
                  value: 1, strokeWidth: 6,
                  color: Colors.white.withOpacity(0.12))),
          SizedBox(width: 60, height: 60,
              child: CircularProgressIndicator(
                  value: pct, strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  strokeCap: StrokeCap.round)),
          Text('${(pct * 100).round()}%',
              style: TextStyle(
                  color: barColor == Colors.white ? Colors.white : barColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    ]);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _fmtDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['','ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
      final d = dt.day.toString();
      final m = months[dt.month];
      final y = (dt.year + 543).toString();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d $m $y  $h:$min';
    } catch (_) { return ''; }
  }



  // ── No Exam Banner ───────────────────────────────────────────────────────
  Widget _noExamBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ExamListScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _P.blueLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _P.blue.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _P.blue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('เริ่มทำข้อสอบครั้งแรก!',
                style: TextStyle(
                    color: _P.textPri, fontSize: 14,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('จำลองสอบ TOEIC 200 ข้อ เพื่อดูสถิติ',
                style: TextStyle(color: _P.textSec, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: _P.blue),
        ]),
      ),
    );
  }

  // ── Quick Actions ────────────────────────────────────────────────────────
  Widget _quickActions(BuildContext context) {
    final actions = [
      _Action('Vocabulary', Icons.collections_bookmark_rounded,
          _P.teal, _P.tealBg,
          () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const VocabListScreen()))),
      _Action('Part Practice', Icons.style_rounded,
          _P.purple, _P.purpleBg,
          () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PartPracticeSelectorScreen()))),
      _Action('Full Mock Test', Icons.assignment_rounded,
          _P.blue, _P.blueLight,
          () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ExamListScreen()))),
      _Action('History', Icons.bar_chart_rounded,
          _P.amber, _P.amberBg,
          () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const StudyHistoryScreen()))),
    ];

    return Row(
      children: actions.map((a) => Expanded(
        child: GestureDetector(
          onTap: a.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: a.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(a.icon, color: a.color, size: 24),
              ),
              const SizedBox(height: 7),
              Text(a.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _P.textPri,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      )).toList(),
    );
  }

  // ── AI Card ──────────────────────────────────────────────────────────────
  Widget _label(String title, {String? sub}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title,
            style: const TextStyle(
                color: _P.textPri, fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        if (sub != null) ...[
          const SizedBox(width: 8),
          Text(sub,
              style: const TextStyle(
                  color: _P.textMute, fontSize: 11)),
        ],
      ],
    );
  }
}

// ── Sticky Header ─────────────────────────────────────────────────────────────
class _StickyHeader extends SliverPersistentHeaderDelegate {
  final String userName;
  final int    bookmarkCount;
  final double statusBarHeight;   // ← รับ status bar จากภายนอก
  final VoidCallback onBookmarkTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onStatisticsTap;

  const _StickyHeader({
    required this.userName,
    required this.bookmarkCount,
    required this.statusBarHeight,
    required this.onBookmarkTap,
    required this.onNotificationsTap,
    required this.onProfileTap,
    required this.onStatisticsTap,
  });

  // content height (ไม่รวม status bar)
  static const _contentMax = 64.0;
  static const _contentMin = 52.0;

  // min/max ต้องรวม statusBar เพื่อ SliverGeometry ถูกต้อง
  @override double get maxExtent => _contentMax + statusBarHeight;
  @override double get minExtent => _contentMin + statusBarHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is! _StickyHeader) return true;
    return oldDelegate.userName       != userName       ||
           oldDelegate.bookmarkCount  != bookmarkCount  ||
           oldDelegate.statusBarHeight != statusBarHeight;
  }

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    final range   = maxExtent - minExtent;
    final shrink  = shrinkOffset.clamp(0.0, range);
    final compact = range > 0 && shrink / range > 0.5;

    return Container(
      decoration: BoxDecoration(
        color: _P.bg,
        border: overlaps
            ? const Border(bottom: BorderSide(color: _P.border))
            : null,
      ),
      // ใช้ Padding(top: statusBarHeight) แทน SafeArea
      // เพื่อไม่ให้ layout เพิ่ม size หลัง SliverGeometry คำนวณแล้ว
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: compact
                  ? Text('สวัสดี, $userName 👋',
                      style: const TextStyle(
                          color: _P.textPri,
                          fontSize: 16,
                          fontWeight: FontWeight.w700))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('สวัสดี, $userName 👋',
                            style: const TextStyle(
                                color: _P.textPri,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        const Text('TOEIC VocabBoost',
                            style: TextStyle(
                                color: _P.textMute, fontSize: 12)),
                      ],
                    ),
            ),
            // ── Action icons ─────────────────────────────────
            _iconBtn(Icons.bar_chart_rounded,     onStatisticsTap),
            const SizedBox(width: 8),
            _iconBtn(Icons.person_outline_rounded, onProfileTap),
            const SizedBox(width: 8),
            _iconBtn(Icons.notifications_outlined, onNotificationsTap),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onBookmarkTap,
              child: Stack(alignment: Alignment.topRight, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _P.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _P.border),
                  ),
                  child: Icon(
                    bookmarkCount > 0
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: bookmarkCount > 0 ? _P.blue : _P.textSec,
                    size: 20,
                  ),
                ),
                if (bookmarkCount > 0)
                  Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: _P.red, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$bookmarkCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.border),
        ),
        child: Icon(icon, color: _P.textSec, size: 20),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _Action(this.label, this.icon, this.color, this.bg, this.onTap);
}

// ── Dashboard Resources Row (horizontal scroll preview) ───────────────────────
class _DashboardResourcesRow extends StatelessWidget {
  _DashboardResourcesRow();

  final _supabase = Supabase.instance.client;

  static const _typeStyle = {
    'youtube': (Icons.play_circle_rounded,   Color(0xFFE53935), Color(0xFFFFEBEE), Color(0xFFFFCDD2)),
    'article': (Icons.article_rounded,       Color(0xFF1565C0), Color(0xFFE3F2FD), Color(0xFFBBDEFB)),
    'website': (Icons.language_rounded,      Color(0xFF00838F), Color(0xFFE0F7FA), Color(0xFFB2EBF2)),
    'other':   (Icons.link_rounded,          Color(0xFF6A1B9A), Color(0xFFF3E5F5), Color(0xFFE1BEE7)),
  };

  static const _typeLabel = {
    'youtube': 'YouTube',
    'article': 'บทความ',
    'website': 'เว็บไซต์',
    'other':   'อื่นๆ',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('learning_resources')
          .stream(primaryKey: ['id'])
          .eq('is_pinned', true)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        // ── Loading ─────────────────────────────────────────────────────
        if (!snapshot.hasData) {
          return SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, __) => _SkeletonCard(),
            ),
          );
        }

        final items = snapshot.data!;

        // ── Empty ───────────────────────────────────────────────────────
        if (items.isEmpty) {
          return Container(
            height: 80,
            decoration: BoxDecoration(
              color: _P.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _P.border),
            ),
            child: const Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_rounded, color: _P.textMute, size: 18),
                SizedBox(width: 8),
                Text('ยังไม่มีแหล่งเรียนรู้',
                    style: TextStyle(color: _P.textMute, fontSize: 13)),
              ]),
            ),
          );
        }

        // ── Cards ───────────────────────────────────────────────────────
        return SizedBox(
          height: 172,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(right: 4),
            itemCount: items.length + 1, // +1 for "see all" button
            itemBuilder: (context, index) {
              // Last item = "ดูทั้งหมด"
              if (index == items.length) {
                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LearningResourcesScreen()),
                    ),
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: _P.blueLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _P.blue.withOpacity(0.18)),
                      ),
                      child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_view_rounded,
                                color: _P.blue, size: 24),
                            SizedBox(height: 8),
                            Text('ดูทั้งหมด',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _P.blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                  ),
                );
              }

              final item = items[index];
              final type = (item['type'] as String?) ?? 'other';
              final style = _typeStyle[type] ?? _typeStyle['other']!;
              final (icon, color, bg, badgeBg) = style;
              final label = _typeLabel[type] ?? 'อื่นๆ';
              final title = (item['title'] as String?) ?? '';
              final desc  = (item['description'] as String?) ?? '';

              return Padding(
                padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 10),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResourceDetailScreen(
                        resource: LearningResource.fromMap(item),
                      ),
                    ),
                  ),
                  child: Container(
                    width: 156,
                    decoration: BoxDecoration(
                      color: _P.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _P.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // ── Top accent ─────────────────────────────────
                      Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: Stack(children: [
                          // Decorative circle
                          Positioned(
                            right: -12, bottom: -12,
                            child: Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.1),
                              ),
                            ),
                          ),
                          // Icon
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(icon,
                                  color: color, size: 20),
                            ),
                          ),
                          // Badge
                          Positioned(
                            right: 8, top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 9,
                                      fontWeight:
                                          FontWeight.w700)),
                            ),
                          ),
                        ]),
                      ),

                      // ── Text ───────────────────────────────────────
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      color: _P.textPri,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Expanded(
                                  child: Text(desc,
                                      style: const TextStyle(
                                          color: _P.textSec,
                                          fontSize: 10,
                                          height: 1.4),
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // ── Footer tap cue ────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _P.surfaceAlt,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text('ดูรายละเอียด',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 9, color: color),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Skeleton loading card ─────────────────────────────────────────────────────
class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.05 + _anim.value * 0.08;
        return Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Container(
            width: 156, height: 172,
            decoration: BoxDecoration(
              color: _P.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _P.border),
            ),
            child: Column(children: [
              Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(opacity),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Container(
                    height: 10, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10, width: 90,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(opacity * 0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}