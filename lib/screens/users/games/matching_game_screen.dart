import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchingGameScreen extends StatefulWidget {
  const MatchingGameScreen({super.key});

  @override
  State<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends State<MatchingGameScreen> {
  final _supabase = Supabase.instance.client;

  final Random _random = Random();
  List<Map<String, dynamic>> _shuffledCards = [];
  Set<int> _flippedIndices = {};
  Set<int> _matchedIndices = {};

  int? _firstFlipped;
  int _score = 0;
  int _moves = 0;
  int _round = 1;
  int _lives = 3;
  int _timeLeft = 45;

  bool _isLoading = true;
  bool _isChecking = false;
  bool _isGameOver = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  Future<void> _startRound() async {
    _timer?.cancel();

    try {
      final pairCount = min(8, 3 + _round);
      final response = await _supabase
          .from('vocabulary')
          .select('headword, Translation_TH')
          .not('Translation_TH', 'is', null)
          .limit(80);

      final pool = List<Map<String, dynamic>>.from(response)..shuffle(_random);
      final selected = pool.take(pairCount).toList();

      final cards = <Map<String, dynamic>>[];
      for (int i = 0; i < selected.length; i++) {
        cards.add({
          'type': 'word',
          'text': selected[i]['headword'],
          'pairId': i,
        });
        cards.add({
          'type': 'translation',
          'text': selected[i]['Translation_TH'],
          'pairId': i,
        });
      }
      cards.shuffle(_random);

      if (!mounted) return;
      setState(() {
        _shuffledCards = cards;
        _flippedIndices = {};
        _matchedIndices = {};
        _firstFlipped = null;
        _isChecking = false;
        _isLoading = false;
        _timeLeft = max(20, 45 - (_round - 1) * 2);
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _isGameOver) return;
        setState(() {
          _timeLeft -= 1;
        });
        if (_timeLeft <= 0) {
          _loseLife();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loseLife() {
    if (_isGameOver) return;

    _timer?.cancel();
    setState(() {
      _lives -= 1;
    });

    if (_lives <= 0) {
      _finishGame();
    } else {
      _startRound();
    }
  }

  void _onCardTap(int index) {
    if (_isGameOver ||
        _isChecking ||
        _matchedIndices.contains(index) ||
        _flippedIndices.contains(index)) {
      return;
    }

    setState(() {
      _flippedIndices.add(index);

      if (_firstFlipped == null) {
        _firstFlipped = index;
      } else {
        _moves++;
        _isChecking = true;

        final first = _shuffledCards[_firstFlipped!];
        final second = _shuffledCards[index];

        if (first['pairId'] == second['pairId']) {
          _matchedIndices.add(_firstFlipped!);
          _matchedIndices.add(index);
          _score += 10 + (_round * 2);
          _isChecking = false;
          _firstFlipped = null;

          if (_matchedIndices.length == _shuffledCards.length) {
            _score += 15;
            _round += 1;
            _startRound();
          }
        } else {
          Future.delayed(const Duration(milliseconds: 550), () {
            if (!mounted) return;
            setState(() {
              _flippedIndices.remove(_firstFlipped);
              _flippedIndices.remove(index);
              _firstFlipped = null;
              _isChecking = false;
            });
          });
        }
      }
    });
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
          'game_type': 'matching',
          'score': _score,
          'moves': _moves,
        });
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('เกมจบแล้ว'),
        content: Text(
          'คะแนน: $_score\nรอบที่ผ่าน: ${_round - 1}\nจำนวนครั้ง: $_moves',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _score = 0;
                _moves = 0;
                _round = 1;
                _lives = 3;
                _isGameOver = false;
              });
              _startRound();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('จับคู่คำศัพท์ - Endless'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/games/leaderboard'),
            icon: const Icon(Icons.emoji_events),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        'Round $_round',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Score $_score'),
                      Text('Lives $_lives'),
                      Text('⏱ $_timeLeft'),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: _shuffledCards.length,
                    itemBuilder: (context, index) {
                      final isFlipped =
                          _flippedIndices.contains(index) ||
                          _matchedIndices.contains(index);
                      final card = _shuffledCards[index];

                      return GestureDetector(
                        onTap: () => _onCardTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _matchedIndices.contains(index)
                                  ? [
                                      Colors.green.shade100,
                                      Colors.green.shade50,
                                    ]
                                  : isFlipped
                                  ? [Colors.blue.shade100, Colors.blue.shade50]
                                  : [
                                      Colors.indigo.shade200,
                                      Colors.indigo.shade400,
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: isFlipped
                                ? Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      card['text'],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: card['type'] == 'word'
                                            ? 18
                                            : 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.question_mark,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
