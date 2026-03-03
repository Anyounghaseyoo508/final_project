import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class SentenceCompletionScreen extends StatefulWidget {
  const SentenceCompletionScreen({super.key});

  @override
  State<SentenceCompletionScreen> createState() => _SentenceCompletionScreenState();
}

class _SentenceCompletionScreenState extends State<SentenceCompletionScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  String? _selectedAnswer;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final response = await _supabase
          .from('vocabulary')
          .select('headword, Example_Sentence, Translation_TH')
          .not('Example_Sentence', 'is', null)
          .limit(10);

      final questions = List<Map<String, dynamic>>.from(response).map((item) {
        final sentence = item['Example_Sentence'] as String;
        final word = item['headword'] as String;
        
        final blanked = sentence.replaceFirst(
          RegExp(word, caseSensitive: false),
          '_____',
        );

        final wrongWords = ['answer', 'question', 'problem', 'solution'];
        final options = [word, ...wrongWords.take(3)];
        options.shuffle(Random());

        return {
          'sentence': blanked,
          'correct': word,
          'options': options,
          'translation': item['Translation_TH'],
        };
      }).toList();

      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _checkAnswer() {
    if (_selectedAnswer == null) return;

    setState(() => _showResult = true);

    if (_selectedAnswer == _questions[_currentIndex]['correct']) {
      _score += 10;
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedAnswer = null;
          _showResult = false;
        });
      } else {
        _saveScore();
      }
    });
  }

  Future<void> _saveScore() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('game_scores').insert({
        'user_id': user.id,
        'game_type': 'sentence_completion',
        'score': _score,
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎉 เสร็จสิ้น!'),
            content: Text('คะแนนรวม: $_score/${_questions.length * 10}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('เติมคำในประโยค')),
        body: const Center(child: Text('ไม่มีข้อมูล')),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('ข้อ ${_currentIndex + 1}/${_questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('คะแนน: $_score')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  question['sentence'],
                  style: const TextStyle(fontSize: 18, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ...List.generate(
              (question['options'] as List).length,
              (index) {
                final option = question['options'][index];
                final isSelected = _selectedAnswer == option;
                final isCorrect = option == question['correct'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: _showResult ? null : () {
                      setState(() => _selectedAnswer = option);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: _showResult
                          ? (isCorrect ? Colors.green : (isSelected ? Colors.red : null))
                          : (isSelected ? Colors.blue : null),
                    ),
                    child: Text(option, style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
            const Spacer(),
            if (!_showResult)
              ElevatedButton(
                onPressed: _selectedAnswer == null ? null : _checkAnswer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.indigo,
                ),
                child: const Text('ตรวจคำตอบ', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }
}
