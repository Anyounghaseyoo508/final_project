import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class MatchingGameScreen extends StatefulWidget {
  const MatchingGameScreen({super.key});

  @override
  State<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends State<MatchingGameScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _words = [];
  List<Map<String, dynamic>> _shuffledCards = [];
  Set<int> _flippedIndices = {};
  Set<int> _matchedIndices = {};
  int? _firstFlipped;
  int _score = 0;
  int _moves = 0;
  bool _isLoading = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    try {
      final response = await _supabase
          .from('vocabulary')
          .select('headword, Translation_TH')
          .limit(6);

      final words = List<Map<String, dynamic>>.from(response);
      final cards = <Map<String, dynamic>>[];

      for (int i = 0; i < words.length; i++) {
        cards.add({'type': 'word', 'text': words[i]['headword'], 'pairId': i});
        cards.add({'type': 'translation', 'text': words[i]['Translation_TH'], 'pairId': i});
      }

      cards.shuffle(Random());

      setState(() {
        _words = words;
        _shuffledCards = cards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onCardTap(int index) {
    if (_isChecking || _matchedIndices.contains(index) || _flippedIndices.contains(index)) return;

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
          _score += 10;
          _isChecking = false;
          _firstFlipped = null;

          if (_matchedIndices.length == _shuffledCards.length) {
            _saveScore();
          }
        } else {
          Future.delayed(const Duration(milliseconds: 800), () {
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

  Future<void> _saveScore() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('game_scores').insert({
        'user_id': user.id,
        'game_type': 'matching',
        'score': _score,
        'moves': _moves,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎉 เยี่ยมมาก!'),
            content: Text('คะแนน: $_score\nจำนวนครั้ง: $_moves'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadGame();
                  setState(() {
                    _flippedIndices.clear();
                    _matchedIndices.clear();
                    _firstFlipped = null;
                    _score = 0;
                    _moves = 0;
                  });
                },
                child: const Text('เล่นอีกครั้ง'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จับคู่คำศัพท์'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('คะแนน: $_score | ครั้ง: $_moves')),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _shuffledCards.length,
              itemBuilder: (context, index) {
                final isFlipped = _flippedIndices.contains(index) || _matchedIndices.contains(index);
                final card = _shuffledCards[index];

                return GestureDetector(
                  onTap: () => _onCardTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _matchedIndices.contains(index)
                          ? Colors.green.shade100
                          : isFlipped
                              ? Colors.blue.shade50
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _matchedIndices.contains(index)
                            ? Colors.green
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isFlipped
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                card['text'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: card['type'] == 'word' ? 18 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : const Icon(Icons.question_mark, size: 40),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
