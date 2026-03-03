import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({super.key});

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  final _supabase = Supabase.instance.client;
  
  List<String> _targetWords = [];
  List<List<String>> _grid = [];
  Set<String> _foundWords = {};
  List<Point<int>> _selectedCells = [];
  bool _isLoading = true;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    try {
      final response = await _supabase
          .from('vocabulary')
          .select('headword')
          .limit(5);

      final words = List<Map<String, dynamic>>.from(response)
          .map((e) => (e['headword'] as String).toUpperCase())
          .where((w) => w.length >= 3 && w.length <= 8)
          .toList();

      setState(() {
        _targetWords = words;
        _grid = _generateGrid(words);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<List<String>> _generateGrid(List<String> words) {
    const size = 10;
    final grid = List.generate(size, (_) => List.filled(size, ''));
    final random = Random();

    for (var word in words) {
      bool placed = false;
      int attempts = 0;

      while (!placed && attempts < 50) {
        final row = random.nextInt(size);
        final col = random.nextInt(size);
        final horizontal = random.nextBool();

        if (horizontal && col + word.length <= size) {
          bool canPlace = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[row][col + i].isNotEmpty && grid[row][col + i] != word[i]) {
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
          bool canPlace = true;
          for (int i = 0; i < word.length; i++) {
            if (grid[row + i][col].isNotEmpty && grid[row + i][col] != word[i]) {
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
          grid[i][j] = String.fromCharCode(65 + random.nextInt(26));
        }
      }
    }

    return grid;
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
        _score += word.length * 5;
        _selectedCells.clear();
      });

      if (_foundWords.length == _targetWords.length) {
        _saveScore();
      }
    }
  }

  Future<void> _saveScore() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('game_scores').insert({
        'user_id': user.id,
        'game_type': 'word_search',
        'score': _score,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎉 ยอดเยี่ยม!'),
            content: Text('คะแนน: $_score'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาคำศัพท์'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('คะแนน: $_score')),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
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
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
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
                                color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  _grid[row][col],
                                  style: const TextStyle(
                                    fontSize: 16,
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
