import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _supabase = Supabase.instance.client;

  int _totalTests = 0;
  int _totalGames = 0;
  double _avgScore = 0;
  double _avgAccuracy = 0;
  double _avgSecondsPerQuestion = 0;
  List<Map<String, dynamic>> _recentScores = [];
  List<_PartInsight> _partInsights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final testsResponse = await _supabase
          .from('exam_submissions')
          .select(
              'score, total_questions, duration_seconds, created_at, answers, questions_snapshot')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final tests = List<Map<String, dynamic>>.from(testsResponse);

      final gamesResponse = await _supabase
          .from('game_scores')
          .select('id')
          .eq('user_id', user.id);

      final totalTests = tests.length;
      final avgScore = tests.isEmpty
          ? 0.0
          : tests
                  .map((e) => (e['score'] as num?)?.toDouble() ?? 0)
                  .reduce((a, b) => a + b) /
              tests.length;

      final partStats = <int, _PartAccumulator>{};
      int allCorrect = 0;
      int allQuestions = 0;
      int totalDurationSeconds = 0;
      int durationTests = 0;

      for (final submission in tests) {
        final questionsRaw = submission['questions_snapshot'];
        final answersRaw = submission['answers'];
        final durationSeconds =
            (submission['duration_seconds'] as num?)?.toInt();
        final totalQuestions =
            (submission['total_questions'] as num?)?.toInt() ?? 0;

        if (durationSeconds != null && totalQuestions > 0) {
          totalDurationSeconds += durationSeconds;
          durationTests += 1;
        }

        if (questionsRaw is! List || answersRaw is! Map) continue;

        final questions = List<Map<String, dynamic>>.from(
          questionsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)),
        );
        final answers = Map<String, dynamic>.from(answersRaw);

        for (int i = 0; i < questions.length; i++) {
          final q = questions[i];
          final part = (q['part'] as num?)?.toInt() ?? 0;
          final correctAnswer = q['correct_answer'];
          final userAnswer = answers['$i'];
          final isCorrect = userAnswer != null && userAnswer == correctAnswer;

          final bucket = partStats.putIfAbsent(part, () => _PartAccumulator());
          bucket.total += 1;
          if (isCorrect) {
            bucket.correct += 1;
            allCorrect += 1;
          }
          allQuestions += 1;
        }
      }

      final partInsights = partStats.entries
          .map(
            (e) => _PartInsight(
              part: e.key,
              correct: e.value.correct,
              total: e.value.total,
            ),
          )
          .toList()
        ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

      final recentScores = tests.length <= 7
          ? tests
          : tests.sublist(tests.length - 7, tests.length);

      setState(() {
        _totalTests = totalTests;
        _totalGames = gamesResponse.length;
        _avgScore = avgScore;
        _avgAccuracy =
            allQuestions == 0 ? 0 : (allCorrect * 100 / allQuestions);
        _avgSecondsPerQuestion = allQuestions == 0 || durationTests == 0
            ? 0
            : totalDurationSeconds / allQuestions;
        _recentScores = recentScores;
        _partInsights = partInsights;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดสถิติไม่สำเร็จ: $e')),
      );
    }
  }

  String _timeSuggestion() {
    if (_avgSecondsPerQuestion == 0) return 'ยังไม่มีข้อมูลเวลาในการทำข้อสอบ';
    if (_avgSecondsPerQuestion > 55) {
      return 'คุณใช้เวลาเฉลี่ยค่อนข้างนาน แนะนำฝึกจับเวลา Part 5/6 เพิ่ม';
    }
    if (_avgSecondsPerQuestion > 40) {
      return 'เวลาเฉลี่ยอยู่ในระดับกลาง ลองซ้อมแบบจับเวลาต่อเนื่องอีกเล็กน้อย';
    }
    return 'การบริหารเวลาอยู่ในเกณฑ์ดี รักษาจังหวะนี้ไว้ได้เลย';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สถิติและความคืบหน้า')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _statCard('ทำข้อสอบ', '$_totalTests',
                              Icons.quiz, Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard('เล่นเกม', '$_totalGames',
                              Icons.sports_esports, Colors.deepPurple)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _statCard(
                              'คะแนนเฉลี่ย',
                              _avgScore.toStringAsFixed(1),
                              Icons.insights,
                              Colors.orange)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                              'ความแม่นยำ',
                              '${_avgAccuracy.toStringAsFixed(1)}%',
                              Icons.check_circle,
                              Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('แนวโน้มคะแนน 7 ครั้งล่าสุด',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_recentScores.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _recentScores
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(
                                      e.key.toDouble(),
                                      ((e.value['score'] as num?)?.toDouble() ??
                                          0)))
                                  .toList(),
                              isCurved: true,
                              barWidth: 3,
                              color: Colors.blue,
                              dotData: const FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('ยังไม่มีผลสอบล่าสุด'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text('จุดที่ควรปรับปรุง (ตาม Part)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_partInsights.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Text('ยังไม่มีข้อมูลเพียงพอสำหรับวิเคราะห์ Part'),
                      ),
                    )
                  else
                    ..._partInsights.take(5).map(
                          (insight) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.auto_graph,
                                  color: Colors.orange),
                              title: Text('Part ${insight.part}'),
                              subtitle: Text(
                                  'ถูก ${insight.correct}/${insight.total} ข้อ'),
                              trailing: Text(
                                '${insight.accuracy.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(
                          'เวลาเฉลี่ยต่อข้อ: ${_avgSecondsPerQuestion.toStringAsFixed(1)} วินาที'),
                      subtitle: Text(_timeSuggestion()),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 22, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _PartAccumulator {
  int correct = 0;
  int total = 0;
}

class _PartInsight {
  final int part;
  final int correct;
  final int total;

  _PartInsight(
      {required this.part, required this.correct, required this.total});

  double get accuracy => total == 0 ? 0 : (correct * 100 / total);
}
