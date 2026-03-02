import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/vocab_model.dart';
import '../../../services/tts_service.dart';
import 'vocab_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _VocabHit {
  final Map<String, dynamic> raw;
  final Vocabulary vocab;
  _VocabHit(this.raw, this.vocab);
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  String searchQuery = '';
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<_VocabHit> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchQuery = '';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      searchQuery = query;
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _supabase
          .from('vocabularies')
          .select()
          .or('headword.ilike.%$query%,Translation_TH.ilike.%$query%')
          .limit(50);

      setState(() {
        _searchResults = (response as List)
            .map((map) => _VocabHit(map, Vocabulary.fromMap(map)))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการเชื่อมต่อข้อมูล';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาคำศัพท์'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'พิมพ์คำศัพท์ หรือความหมายภาษาไทย...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            searchQuery = '';
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) => _performSearch(value),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    if (searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_search, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'พิมพ์เพื่อค้นหาคำศัพท์จากฐานข้อมูล',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('ไม่พบคำศัพท์ที่ตรงกัน'));
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blueAccent.withOpacity(0.05),
          child: Text(
            'ผลลัพธ์: ${_searchResults.length} รายการ',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
                fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) =>
                _buildVocabCard(_searchResults[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildVocabCard(_VocabHit hit) {
    final vocab = hit.vocab;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            VocabDetailScreen.routeName,
            arguments: hit.raw,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    vocab.cefr.isEmpty ? '-' : vocab.cefr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            vocab.headword,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (vocab.pos.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(${vocab.pos})',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vocab.translationTH,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                  onPressed: () => _ttsService.speak(vocab.headword),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
