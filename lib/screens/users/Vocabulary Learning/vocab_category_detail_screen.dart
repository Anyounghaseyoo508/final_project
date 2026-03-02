import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/tts_service.dart';
import '../../../models/vocab_model.dart';
import 'vocab_detail_screen.dart';

class VocabCategoryDetailScreen extends StatefulWidget {
  final String categoryLevel;
  final String categoryTitle;

  const VocabCategoryDetailScreen({
    super.key,
    required this.categoryLevel,
    required this.categoryTitle,
  });

  @override
  State<VocabCategoryDetailScreen> createState() =>
      _VocabCategoryDetailScreenState();
}

class _VocabCategoryDetailScreenState
    extends State<VocabCategoryDetailScreen> {
  // ── Palette เดียวกับ MainShell ─────────────────────────────────────────
  static const _bg      = Color(0xFFF0F4F8);
  static const _blue    = Color(0xFF1A56DB);
  static const _blueL   = Color(0xFFEEF3FF);
  static const _border  = Color(0xFFE2E8F0);
  static const _textPri = Color(0xFF0F1729);
  static const _textSec = Color(0xFF64748B);

  String searchQuery = '';
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _future;
  int _totalCount = 0;

  Future<List<Map<String, dynamic>>> _fetchVocabs() async {
    try {
      final response = await _supabase
          .from('vocabularies')
          .select()
          .ilike('CEFR', widget.categoryLevel.trim())
          .order('headword', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error: $e');
      return [];
    }
  }

  Future<void> _getTotalCount() async {
    try {
      final response = await _supabase
          .from('vocabularies')
          .select()
          .ilike('CEFR', widget.categoryLevel.trim())
          .count(CountOption.exact);
      setState(() => _totalCount = response.count);
    } catch (e) {
      debugPrint('Error counting rows: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _ttsService.init();
    _future = _fetchVocabs();
    _getTotalCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _blue,
        elevation: 0,
        title: Text(
          widget.categoryTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาในระดับ ${widget.categoryLevel}...',
                hintStyle: const TextStyle(color: _textSec, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: _textSec, size: 20),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blue, width: 1.5),
                ),
              ),
              onChanged: (value) =>
                  setState(() => searchQuery = value.trim().toLowerCase()),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _blue));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('เกิดข้อผิดพลาด: ${snapshot.error}',
                          style: const TextStyle(color: _textSec)));
                }

                final rawData = snapshot.data ?? [];

                if (rawData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: _blueL,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.search_off_rounded,
                              size: 40, color: _blue),
                        ),
                        const SizedBox(height: 14),
                        Text('ไม่พบคำศัพท์ในระดับ ${widget.categoryLevel}',
                            style: const TextStyle(color: _textSec)),
                      ],
                    ),
                  );
                }

                final filteredItems = rawData.where((item) {
                  final v = Vocabulary.fromMap(item);
                  if (searchQuery.isEmpty) return true;
                  return v.headword
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()) ||
                      v.translationTH
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase());
                }).toList();

                return Column(
                  children: [
                    // Summary bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _blueL,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ทั้งหมด $_totalCount คำ',
                              style: const TextStyle(
                                color: _blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (searchQuery.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'พบ ${filteredItems.length} คำ',
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _border),

                    // List
                    Expanded(
                      child: filteredItems.isEmpty && searchQuery.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                        color: _blueL,
                                        borderRadius:
                                            BorderRadius.circular(18)),
                                    child: const Icon(
                                        Icons.search_off_rounded,
                                        size: 36,
                                        color: _blue),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('ไม่พบคำศัพท์ที่ตรงกับการค้นหา',
                                      style: TextStyle(color: _textSec)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: _border),
                              padding: const EdgeInsets.only(bottom: 32),
                              itemBuilder: (context, index) {
                                final itemData = filteredItems[index];
                                final v = Vocabulary.fromMap(itemData);
                                return _VocabTile(
                                  v: v,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    VocabDetailScreen.routeName,
                                    arguments: itemData,
                                  ),
                                  onSpeak: () =>
                                      _ttsService.speak(v.headword),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabTile extends StatelessWidget {
  final Vocabulary v;
  final VoidCallback onTap;
  final VoidCallback onSpeak;

  const _VocabTile(
      {required this.v, required this.onTap, required this.onSpeak});

  static const _blue    = Color(0xFF1A56DB);
  static const _blueL   = Color(0xFFEEF3FF);
  static const _textPri = Color(0xFF0F1729);
  static const _textSec = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _blueL,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    v.cefr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.headword,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _textPri,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v.translationTH,
                      style: const TextStyle(
                          fontSize: 13, color: _textSec),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded,
                    color: _blue, size: 20),
                onPressed: onSpeak,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
