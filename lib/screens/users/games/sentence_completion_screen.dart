import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SentenceCompletionScreen extends StatefulWidget {
  const SentenceCompletionScreen({super.key});

  @override
  State<SentenceCompletionScreen> createState() =>
      _SentenceCompletionScreenState();
}

class _SentenceCompletionScreenState extends State<SentenceCompletionScreen> {
  final _supabase = Supabase.instance.client;
  final _random = Random();

  List<Map<String, dynamic>> _pool = [];
  Map<String, dynamic>? _currentQuestion;

  int _score = 0;
  int _lives = 3;
  int _streak = 0;
  int _round = 1;
  int _timeLeft = 12;

  bool _isLoading = true;
  bool _showResult = false;
  bool _isGameOver = false;
  String? _selectedAnswer;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadPool();
    _nextQuestion();
  }

  Future<void> _loadPool() async {
    try {
      final response = await _supabase
          .from('vocabularies')
          .select('headword, Example_Sentence')
          .not('Example_Sentence', 'is', null)
          .limit(200);

      final raw = List<Map<String, dynamic>>.from(response).where((e) {
        final sentence = '${e['Example_Sentence'] ?? ''}';
        final word = '${e['headword'] ?? ''}';
        return word.isNotEmpty &&
            sentence.toLowerCase().contains(word.toLowerCase());
      }).toList();

      raw.shuffle(_random);
      _pool = raw;
      _isLoading = false;
    } catch (_) {
      _isLoading = false;
    }
  }

  List<String> _buildOptions(String correct) {
    final candidates =
        _pool
            .map((e) => '${e['headword'] ?? ''}')
            .where(
              (w) => w.isNotEmpty && w.toLowerCase() != correct.toLowerCase(),
            )
            .toList()
          ..shuffle(_random);

    final options = <String>[correct, ...candidates.take(3)]..shuffle(_random);
    return options;
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = max(6, 12 - ((_round - 1) ~/ 3));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isGameOver) return;
      setState(() => _timeLeft -= 1);
      if (_timeLeft <= 0) {
        _loseLife();
      }
    });
  }

  void _nextQuestion() {
    if (_pool.isEmpty) return;

    final item = _pool[_random.nextInt(_pool.length)];
    final sentence = item['Example_Sentence'] as String;
    final word = item['headword'] as String;
    final blanked = sentence.replaceFirst(
      RegExp(word, caseSensitive: false),
      '_____',
    );

    setState(() {
      _currentQuestion = {
        'sentence': blanked,
        'correct': word,
        'options': _buildOptions(word),
      };
      _showResult = false;
      _selectedAnswer = null;
      _round += 1;
    });

    _startTimer();
  }

  void _loseLife() {
    _timer?.cancel();
    setState(() {
      _lives -= 1;
      _streak = 0;
    });
    if (_lives <= 0) {
      _finishGame();
    } else {
      _nextQuestion();
    }
  }

  void _checkAnswer() {
    if (_selectedAnswer == null || _currentQuestion == null) return;

    _timer?.cancel();
    final correct = _selectedAnswer == _currentQuestion!['correct'];

    setState(() => _showResult = true);

    if (correct) {
      setState(() {
        _streak += 1;
        _score += 10 + min(10, _streak);
      });
      Future.delayed(const Duration(milliseconds: 600), _nextQuestion);
    } else {
      Future.delayed(const Duration(milliseconds: 600), _loseLife);
    }
  }

  Future<void> _finishGame() async {
    if (_isGameOver) return;
    _isGameOver = true;
    _timer?.cancel();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('game_scores').insert({
          'user_id': user.id,
          'game_type': 'sentence_completion',
          'score': _score,
        });
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('จบเกมแล้ว'),
        content: Text('คะแนนรวม: $_score\nคำถามที่ผ่าน: ${_round - 1}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _score = 0;
                _lives = 3;
                _round = 1;
                _streak = 0;
                _isGameOver = false;
              });
              _nextQuestion();
            },
            child: const Text('เล่นใหม่'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('ออก'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentQuestion == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('เติมคำในประโยค - Endless')),
        body: const Center(child: Text('ไม่มีข้อมูลเพียงพอสำหรับเล่นเกม')),
      );
    }

    final question = _currentQuestion!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('เติมคำในประโยค - Endless'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/games/leaderboard'),
            icon: const Icon(Icons.emoji_events),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Score: $_score'),
                Text('Lives: $_lives'),
                Text('⏱ $_timeLeft'),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  question['sentence'],
                  style: const TextStyle(fontSize: 20, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate((question['options'] as List).length, (index) {
              final option = question['options'][index] as String;
              final isSelected = _selectedAnswer == option;
              final isCorrect = option == question['correct'];

              Color? bg;
              if (_showResult) {
                if (isCorrect) {
                  bg = Colors.green;
                } else if (isSelected) {
                  bg = Colors.red;
                }
              } else if (isSelected) {
                bg = Colors.blue;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  onPressed: _showResult
                      ? null
                      : () => setState(() => _selectedAnswer = option),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    backgroundColor: bg,
                  ),
                  child: Text(option),
                ),
              );
            }),
            const Spacer(),
            ElevatedButton(
              onPressed: _selectedAnswer == null || _showResult
                  ? null
                  : _checkAnswer,
              child: const Text('ยืนยันคำตอบ'),
            ),
          ],
        ),
      ),
    );
  }
}
