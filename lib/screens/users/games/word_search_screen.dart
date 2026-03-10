import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({super.key});

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  final _supabase = Supabase.instance.client;
  final _random = Random();

  List<String> _targetWords = [];
  List<List<String>> _grid = [];
  Set<String> _foundWords = {};
  List<Point<int>> _selectedCells = [];

  int _score = 0;
  int _lives = 3;
  int _round = 1;
  int _timeLeft = 60;
  bool _isLoading = true;
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
      final response = await _supabase
          .from('vocabulary')
          .select('headword')
          .limit(120);
      final words =
          List<Map<String, dynamic>>.from(response)
              .map((e) => (e['headword'] as String).toUpperCase())
              .where((w) => w.length >= 3 && w.length <= 8)
              .toList()
            ..shuffle(_random);

      final targetCount = min(6, 3 + (_round ~/ 2));
      final target = words.take(targetCount).toList();
      final gridSize = min(12, 8 + (_round ~/ 2));

      if (!mounted) return;
      setState(() {
        _targetWords = target;
        _foundWords = {};
        _selectedCells = [];
        _grid = _generateGrid(target, size: gridSize);
        _isLoading = false;
        _timeLeft = max(25, 60 - _round);
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _isGameOver) return;
        setState(() => _timeLeft -= 1);
        if (_timeLeft <= 0) {
          _loseLife();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<List<String>> _generateGrid(List<String> words, {required int size}) {
    final grid = List.generate(size, (_) => List.filled(size, ''));

    for (final word in words) {
      bool placed = false;
      int attempts = 0;

      while (!placed && attempts < 100) {
        final row = _random.nextInt(size);
        final col = _random.nextInt(size);
        final horizontal = _random.nextBool();

        if (horizontal && col + word.length <= size) {
          var canPlace = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[row][col + i].isNotEmpty &&
                grid[row][col + i] != word[i]) {
              canPlace = false;
              break;
            }
          }
          if (canPlace) {
            for (int i = 0; i < word.length; i++) {
              grid[row][col + i] = word[i];
            }
            placed = true;
          }
        } else if (!horizontal && row + word.length <= size) {
          var canPlace = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[row + i][col].isNotEmpty &&
                grid[row + i][col] != word[i]) {
              canPlace = false;
              break;
            }
          }
          if (canPlace) {
            for (int i = 0; i < word.length; i++) {
              grid[row + i][col] = word[i];
            }
            placed = true;
          }
        }

        attempts++;
      }
    }

    for (int i = 0; i < size; i++) {
      for (int j = 0; j < size; j++) {
        if (grid[i][j].isEmpty) {
          grid[i][j] = String.fromCharCode(65 + _random.nextInt(26));
        }
      }
    }

    return grid;
  }

  void _loseLife() {
    _timer?.cancel();
    setState(() => _lives -= 1);
    if (_lives <= 0) {
      _finishGame();
    } else {
      _startRound();
    }
  }

  void _onCellTap(int row, int col) {
    final point = Point(row, col);

    setState(() {
      if (_selectedCells.contains(point)) {
        _selectedCells.remove(point);
      } else {
        _selectedCells.add(point);
      }
      _checkWord();
    });
  }

  void _checkWord() {
    if (_selectedCells.length < 3) return;

    final word = _selectedCells.map((p) => _grid[p.x][p.y]).join();
    if (_targetWords.contains(word) && !_foundWords.contains(word)) {
      setState(() {
        _foundWords.add(word);
        _score += word.length * 5 + _round;
        _selectedCells.clear();
      });

      if (_foundWords.length == _targetWords.length) {
        _timer?.cancel();
        setState(() {
          _score += 20;
          _round += 1;
        });
        _startRound();
      }
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
          'game_type': 'word_search',
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
        content: Text('คะแนน: $_score\nผ่านไป ${_round - 1} รอบ'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _score = 0;
                _lives = 3;
                _round = 1;
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
        title: const Text('ค้นหาคำศัพท์ - Endless'),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Round $_round'),
                      Text('Score $_score'),
                      Text('Lives $_lives'),
                      Text('⏱ $_timeLeft'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: _targetWords.map((word) {
                      final found = _foundWords.contains(word);
                      return Chip(
                        label: Text(word),
                        backgroundColor: found ? Colors.green.shade100 : null,
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _grid.length,
                          mainAxisSpacing: 3,
                          crossAxisSpacing: 3,
                        ),
                        itemCount: _grid.length * _grid.length,
                        itemBuilder: (context, index) {
                          final row = index ~/ _grid.length;
                          final col = index % _grid.length;
                          final point = Point(row, col);
                          final isSelected = _selectedCells.contains(point);

                          return GestureDetector(
                            onTap: () => _onCellTap(row, col),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade200
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  _grid[row][col],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
