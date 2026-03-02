import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Vocabulary Learning/vocab_list_screen.dart';
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
  const UserDashboardScreen({super.key});

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
  int    _lastL        = 0;
  int    _lastR        = 0;
  int    _scoreTrend   = 0;
  String _lastLevel    = '';
  int    _bookmarkCount= 0;
  List<Map<String, dynamic>> _weakSkills = [];

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
            .select('total_score, l_toeic, r_toeic, cefr_level, created_at')
            .eq('user_id', user.id)
            .not('total_score', 'is', null)
            .order('created_at', ascending: false),
        _supabase.from('user_skills')
            .select('category, correct_count, total_count')
            .eq('user_id', user.id)
            .gt('total_count', 0),
        _supabase.from('bookmarks').select('id').eq('user_id', user.id),
      ]);

      final profile   = futures[0] as Map?;
      final exams     = futures[1] as List;
      final skills    = futures[2] as List;
      final bookmarks = futures[3] as List;

      int best = 0;
      for (final e in exams) {
        final s = (e['total_score'] as num?)?.toInt() ?? 0;
        if (s > best) best = s;
      }
      final lastScore = exams.isNotEmpty ? (exams[0]['total_score'] as num?)?.toInt() ?? 0 : 0;
      final lastL     = exams.isNotEmpty ? (exams[0]['l_toeic']     as num?)?.toInt() ?? 0 : 0;
      final lastR     = exams.isNotEmpty ? (exams[0]['r_toeic']     as num?)?.toInt() ?? 0 : 0;
      final lastLevel = exams.isNotEmpty ? exams[0]['cefr_level']?.toString() ?? '' : '';
      final trend     = exams.length >= 2
          ? lastScore - ((exams[1]['total_score'] as num?)?.toInt() ?? 0) : 0;

      final skillList = skills.map((s) {
        final correct = (s['correct_count'] as num?)?.toInt() ?? 0;
        final total   = (s['total_count']   as num?)?.toInt() ?? 1;
        return {
          'category': s['category']?.toString() ?? '-',
          'accuracy': total > 0 ? (correct / total * 100).round() : 0,
          'correct' : correct,
          'total'   : total,
        };
      }).toList()
        ..sort((a, b) => (a['accuracy'] as int).compareTo(b['accuracy'] as int));

      final name = profile?['display_name']?.toString().trim() ?? '';
      setState(() {
        _userName      = name.isNotEmpty ? name.split(' ').first : 'User';
        _totalExams    = exams.length;
        _lastScore     = lastScore;
        _bestScore     = best;
        _lastL         = lastL;
        _lastR         = lastR;
        _lastLevel     = lastLevel;
        _scoreTrend    = trend;
        _weakSkills    = skillList.take(3).cast<Map<String, dynamic>>().toList();
        _bookmarkCount = bookmarks.length;
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
                onBookmarkTap: () =>
                    Navigator.pushNamed(context, '/bookmarks')
                        .then((_) => _loadStats()),
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

                        const SizedBox(height: 28),

                        // ── Quick Actions ──────────────────────────────
                        _label('เมนูลัด'),
                        const SizedBox(height: 14),
                        _quickActions(context),

                        // ── L/R ────────────────────────────────────────
                        if (_totalExams > 0) ...[
                          const SizedBox(height: 28),
                          _label('Listening vs Reading'),
                          const SizedBox(height: 12),
                          _lrCard(),
                        ],

                        // ── Weak Skills ────────────────────────────────
                        if (_weakSkills.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _label('จุดที่ต้องพัฒนา',
                              sub: 'ต่ำสุด 3 อันดับ'),
                          const SizedBox(height: 12),
                          ..._weakSkills.map((s) => _skillRow(
                                s['category'] as String,
                                s['accuracy'] as int,
                                s['correct']  as int,
                                s['total']    as int,
                              )),
                        ],

                        // ── AI Tutor ───────────────────────────────────
                        const SizedBox(height: 28),
                        _label('AI Tutor'),
                        const SizedBox(height: 12),
                        _aiCard(context),
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
    final pct      = _bestScore / 990;
    final trendUp  = _scoreTrend >= 0;
    final trendStr = _totalExams >= 2
        ? (trendUp ? '+$_scoreTrend' : '$_scoreTrend')
        : null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _P.blue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _P.blue.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('คะแนนสูงสุด',
              style: TextStyle(
                  color: Colors.white70, fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          if (trendStr != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  trendUp
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 11,
                  color: trendUp
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                ),
                const SizedBox(width: 3),
                Text(trendStr,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trendUp
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5))),
              ]),
            ),
        ]),

        const SizedBox(height: 6),

        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$_bestScore',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -2)),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 6),
            child: Text('/ 990',
                style: TextStyle(
                    color: Colors.white54, fontSize: 18)),
          ),
          const Spacer(),
          SizedBox(
            width: 60, height: 60,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                  value: 1, strokeWidth: 5,
                  color: Colors.white.withOpacity(0.15)),
              CircularProgressIndicator(
                value: pct,
                strokeWidth: 5,
                backgroundColor: Colors.transparent,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                strokeCap: StrokeCap.round,
              ),
              Text('${(pct * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),

        const SizedBox(height: 16),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 14),

        Row(children: [
          _chip('ล่าสุด', '$_lastScore'),
          const SizedBox(width: 10),
          if (_lastLevel.isNotEmpty) _chip('ระดับ', _lastLevel),
          const Spacer(),
          Text('$_totalExams ครั้ง',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white60, fontSize: 9,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 1),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ]),
    );
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

  // ── L vs R Card ──────────────────────────────────────────────────────────
  Widget _lrCard() {
    final lPct = (_lastL / 495).clamp(0.0, 1.0);
    final rPct = (_lastR / 495).clamp(0.0, 1.0);
    final gap  = (_lastL - _lastR).abs();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
      ),
      child: Column(children: [
        _barRow('Listening', lPct, _P.teal, _lastL),
        const SizedBox(height: 16),
        _barRow('Reading', rPct, _P.blue, _lastR),
        if (gap > 100) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _P.orangeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: _P.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _lastL > _lastR
                    ? 'Reading ยังต่ำกว่า — แนะนำฝึก Part 5–7'
                    : 'Listening ยังต่ำกว่า — แนะนำฝึก Part 1–4',
                style: const TextStyle(
                    fontSize: 12, color: _P.orange,
                    fontWeight: FontWeight.w500),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _barRow(String label, double pct, Color color, int score) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: const TextStyle(
                color: _P.textSec, fontSize: 12,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$score',
            style: TextStyle(
                color: color, fontSize: 13,
                fontWeight: FontWeight.w700)),
        const Text(' / 495',
            style: TextStyle(color: _P.textMute, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 8,
          backgroundColor: _P.surfaceAlt,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  // ── Skill Row ────────────────────────────────────────────────────────────
  Widget _skillRow(String category, int accuracy, int correct, int total) {
    final (color, bg) = accuracy < 50
        ? (_P.red, _P.redBg)
        : accuracy < 70
            ? (_P.orange, _P.orangeBg)
            : (_P.green, _P.greenBg);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(category,
              style: const TextStyle(
                  color: _P.textPri, fontSize: 13,
                  fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8)),
            child: Text('$accuracy%',
                style: TextStyle(
                    color: color, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 3),
        Text('$correct จาก $total ข้อ',
            style: const TextStyle(
                color: _P.textMute, fontSize: 11)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: accuracy / 100,
            minHeight: 5,
            backgroundColor: _P.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]),
    );
  }

  // ── AI Card ──────────────────────────────────────────────────────────────
  Widget _aiCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/ai-tutor'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _P.border),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _P.purpleBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: _P.purple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('วิเคราะห์จุดอ่อนด้วย AI',
                style: TextStyle(
                    color: _P.textPri, fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              _totalExams > 0
                  ? 'ใช้ข้อมูลจากข้อสอบ $_totalExams ครั้ง'
                  : 'ทำข้อสอบก่อนเพื่อให้ AI วิเคราะห์ได้',
              style: const TextStyle(
                  color: _P.textSec, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: _P.textMute),
        ]),
      ),
    );
  }

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
  final VoidCallback onBookmarkTap;   // ← รับ callback จากภายนอก

  const _StickyHeader({
    required this.userName,
    required this.bookmarkCount,
    required this.onBookmarkTap,
  });

  static const _max = 88.0;
  static const _min = 64.0;

  @override double get maxExtent => _max;
  @override double get minExtent => _min;

  @override
  bool shouldRebuild(_StickyHeader old) =>
      old.userName != userName || old.bookmarkCount != bookmarkCount;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    final compact = shrink / (_max - _min) > 0.5;

    return Container(
      decoration: BoxDecoration(
        color: _P.bg,
        border: overlaps
            ? const Border(bottom: BorderSide(color: _P.border))
            : null,
      ),
      child: SafeArea(
        bottom: false,
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
