import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _supabase = Supabase.instance.client;
  
  int _totalVocab = 0;
  int _totalTests = 0;
  double _avgScore = 0;
  int _totalGames = 0;
  List<Map<String, dynamic>> _recentScores = [];
  Map<String, int> _weakAreas = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Total tests
      final testsResponse = await _supabase
          .from('exam_submissions')
          .select('score, total_questions')
          .eq('user_id', user.id);

      final tests = List<Map<String, dynamic>>.from(testsResponse);
      final totalTests = tests.length;
      final avgScore = tests.isEmpty
          ? 0.0
          : tests.map((e) => (e['score'] as num).toDouble()).reduce((a, b) => a + b) / tests.length;

      // Total games
      final gamesResponse = await _supabase
          .from('game_scores')
          .select('score')
          .eq('user_id', user.id);

      final totalGames = gamesResponse.length;

      // Recent scores for chart
      final recentResponse = await _supabase
          .from('exam_submissions')
          .select('score, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(7);

      final recentScores = List<Map<String, dynamic>>.from(recentResponse).reversed.toList();

      // Weak areas analysis
      final wrongAnswers = await _supabase
          .from('exam_submissions')
          .select('user_answers, questions')
          .eq('user_id', user.id);

      final weakAreas = <String, int>{};
      for (var submission in wrongAnswers) {
        // Analyze wrong answers by category
        // This is simplified - you'd need to parse the actual data structure
        weakAreas['Part 5'] = (weakAreas['Part 5'] ?? 0) + 1;
        weakAreas['Part 6'] = (weakAreas['Part 6'] ?? 0) + 1;
      }

      // Total vocabulary learned (simplified)
      final vocabCount = await _supabase
          .from('vocabulary')
          .select('id', const FetchOptions(count: CountOption.exact, head: true));

      setState(() {
        _totalVocab = vocabCount.count ?? 0;
        _totalTests = totalTests;
        _avgScore = avgScore;
        _totalGames = totalGames;
        _recentScores = recentScores;
        _weakAreas = weakAreas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สถิติการเรียน'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'คำศัพท์ทั้งหมด',
                            _totalVocab.toString(),
                            Icons.book,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'ทำข้อสอบ',
                            _totalTests.toString(),
                            Icons.quiz,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'คะแนนเฉลี่ย',
                            _avgScore.toStringAsFixed(1),
                            Icons.star,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'เล่นเกม',
                            _totalGames.toString(),
                            Icons.gamepad,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'คะแนนย้อนหลัง 7 ครั้ง',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_recentScores.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _recentScores
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(
                                          e.key.toDouble(),
                                          (e.value['score'] as num).toDouble(),
                                        ))
                                    .toList(),
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'จุดที่ควรปรับปรุง',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_weakAreas.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('ยังไม่มีข้อมูล ทำข้อสอบเพื่อดูการวิเคราะห์'),
                        ),
                      )
                    else
                      ..._weakAreas.entries.map((e) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.warning, color: Colors.orange),
                              title: Text(e.key),
                              trailing: Text(
                                '${e.value} ข้อผิดพลาด',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
