import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/tts_service.dart';
import 'vocab_detail_screen.dart'; // ✅ ต้องมี routeName

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

class _VocabCategoryDetailScreenState extends State<VocabCategoryDetailScreen> {
  String searchQuery = "";
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
    _future = _fetchVocabs();
  }

  Future<List<Map<String, dynamic>>> _fetchVocabs() {
    // ✅ แนะนำ: ใส่ order ที่ DB เลย แล้วค่อย sort ซ้ำฝั่ง client ก็ได้
    return _supabase
        .from('vocabularies')
        .select()
        .eq('CEFR', widget.categoryLevel);
  }

  String _s(dynamic v) => (v ?? '').toString();
  String _lower(dynamic v) => _s(v).toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาคำศัพท์ในระดับ ${widget.categoryLevel}...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) =>
                  setState(() => searchQuery = value.trim().toLowerCase()),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;

                // ✅ Filter (search หลายฟิลด์) + Sort A-Z
                final filtered = data.where((m) {
                  if (searchQuery.isEmpty) return true;

                  return _lower(m['headword']).contains(searchQuery) ||
                      _lower(m['Translation_TH']).contains(searchQuery) ||
                      _lower(m['POS']).contains(searchQuery) ||
                      _lower(m['Definition_TH']).contains(searchQuery) ||
                      _lower(m['Definition_EN']).contains(searchQuery) ||
                      _lower(m['Example_Sentence']).contains(searchQuery) ||
                      _lower(m['TOEIC_Category']).contains(searchQuery) ||
                      _lower(m['Synonyms']).contains(searchQuery) ||
                      _lower(m['CEFR']).contains(searchQuery);
                }).toList()
                  ..sort((a, b) => _lower(a['headword']).compareTo(_lower(b['headword'])));

                return Column(
                  children: [
                    // Count
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey.shade100,
                      child: Text(
                        searchQuery.isEmpty
                            ? "ทั้งหมด: ${filtered.length} คำ"
                            : "พบ: ${filtered.length} คำ",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),

                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('ไม่พบคำศัพท์ในหมวดนี้'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              itemBuilder: (context, index) {
                                final m = filtered[index];

                                final headword = _s(m['headword']).isEmpty ? "N/A" : _s(m['headword']);
                                final cefr = _s(m['CEFR']).isEmpty ? "-" : _s(m['CEFR']);
                                final pos = _s(m['POS']);
                                final transTh = _s(m['Translation_TH']);

                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  elevation: 1.5,
                                  shadowColor: Colors.black.withOpacity(0.08),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        VocabDetailScreen.routeName,
                                        arguments: m, // ✅ ส่งทั้ง row ไปหน้า detail
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          // ✅ วงกลม CEFR
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.blueAccent.withOpacity(0.15),
                                            child: Text(
                                              cefr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // ✅ Text block
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        headword,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (pos.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(999),
                                                          border: Border.all(color: Colors.grey.shade200),
                                                        ),
                                                        child: Text(
                                                          pos,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  transTh.isEmpty ? "-" : transTh,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // ✅ TTS
                                          IconButton(
                                            icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                                            onPressed: () async {
                                              await _ttsService.speak(headword);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
