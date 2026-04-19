import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/tts_service.dart';
import '../../../models/vocab_model.dart';
import '../dashboard_screen.dart';

class VocabDetailScreen extends StatefulWidget {
  static const routeName = '/vocab-detail';

  const VocabDetailScreen({super.key});

  @override
  State<VocabDetailScreen> createState() => _VocabDetailScreenState();
}

class _VocabDetailScreenState extends State<VocabDetailScreen> {
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _currentData;
  bool _isLoading = false;
  bool _isBookmarked = false;

  String _s(dynamic v) => (v ?? '').toString().trim();

  List<String> _formatSynonyms(String synData) {
    if (synData.isEmpty || synData == '-') return [];
    return synData
        .replaceAll(RegExp(r"[\[\]']"), '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _ttsService.init();
    Future.microtask(() => _handleArguments());
  }

  void _handleArguments() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() => _currentData = args);
      _checkBookmarkStatus(args['id']);
    } else if (args is String) {
      _loadVocabByHeadword(args);
    }
  }

  Future<void> _checkBookmarkStatus(dynamic vocabId) async {
    final user = _supabase.auth.currentUser;
    if (user == null || vocabId == null) return;

    final response = await _supabase
        .from('bookmarks')
        .select()
        .eq('user_id', user.id)
        .eq('vocab_id', vocabId)
        .maybeSingle();

    if (mounted) {
      setState(() => _isBookmarked = response != null);
    }
  }

  Future<void> _toggleBookmark() async {
    final user = _supabase.auth.currentUser;
    final vocabId = _currentData?['id'];

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบเพื่อบันทึก')),
      );
      return;
    }

    try {
      if (_isBookmarked) {
        await _supabase
            .from('bookmarks')
            .delete()
            .eq('user_id', user.id)
            .eq('vocab_id', vocabId);
        bookmarkCountNotifier.value = (bookmarkCountNotifier.value - 1).clamp(0, 999999);
      } else {
        await _supabase.from('bookmarks').insert({
          'user_id': user.id,
          'vocab_id': vocabId,
        });
        bookmarkCountNotifier.value = bookmarkCountNotifier.value + 1;
      }
      setState(() => _isBookmarked = !_isBookmarked);
    } catch (e) {
      debugPrint('Bookmark Error: $e');
    }
  }

  Future<void> _loadVocabByHeadword(String word) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('vocabularies')
          .select()
          .ilike('headword', cleanWord)
          .limit(1);

      if ((response as List).isNotEmpty) {
        setState(() {
          _currentData = response[0];
          _isLoading = false;
        });
        _checkBookmarkStatus(_currentData!['id']);
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่พบข้อมูลคำว่า "$cleanWord"')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading vocab: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_currentData == null) {
      return const Scaffold(body: Center(child: Text('ไม่พบข้อมูล')));
    }

    final m = _currentData!;
    final v          = Vocabulary.fromMap(m);
    final headword   = v.headword;
    final cefr       = v.cefr;
    final pos        = v.pos;
    final readingEn  = v.readingEn;
    final readingTh  = v.readingTh;
    final transTh    = v.translationTH;
    final defTh      = v.definitionTH;
    final defEn      = v.definitionEN;
    final example    = v.exampleSentence;
    final category   = v.toeicCategory;
    final synonymsRaw = v.synonyms;
    final synList    = _formatSynonyms(synonymsRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text(headword),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _toggleBookmark,
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            color: _isBookmarked ? Colors.orange : Colors.white,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeaderCard(
            headword, cefr, readingEn, readingTh, pos, transTh,
            _isBookmarked, _toggleBookmark,
          ),
          const SizedBox(height: 10),
          _info('ความหมาย (ภาษาไทย)', defTh),
          _info('Definition (English)', defEn),
          _info('ตัวอย่างประโยค', example),
          _info('หมวดหมู่ TOEIC', category),

          // Synonyms
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              'คำเหมือน (Synonyms) - คลิกเพื่อดูรายละเอียด',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blueAccent,
              ),
            ),
          ),
          synList.isEmpty
              ? const Text('-')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: synList.map((syn) {
                    final cleanSyn = syn.trim();
                    return ActionChip(
                      label: Text(cleanSyn),
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          VocabDetailScreen.routeName,
                          arguments: cleanSyn,
                        );
                      },
                      backgroundColor: Colors.blue.shade50,
                      side: BorderSide(color: Colors.blue.shade200),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueAccent,
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    String headword,
    String cefr,
    String readingEn,
    String readingTh,
    String pos,
    String transTh,
    bool isBookmarked,
    VoidCallback onBookmark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headword,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  cefr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _ttsService.speak(headword),
                icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$readingEn  ($readingTh)',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pos,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 32),
          Text(
            transTh,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}