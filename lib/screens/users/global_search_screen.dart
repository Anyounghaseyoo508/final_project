import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/vocab_model.dart';
import '../../services/tts_service.dart';
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
  String searchQuery = "";
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _futureAll;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
    _futureAll = _fetchAllVocabs();
  }

  Future<List<Map<String, dynamic>>> _fetchAllVocabs() {
    // ถ้ายังติด 1000 ให้ใช้ .range(0, 5000)
    return _supabase.from('vocabularies').select();
  }

  Future<void> _refresh() async {
    setState(() => _futureAll = _fetchAllVocabs());
    await _futureAll;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาคำศัพท์ทั้งหมด'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'พิมพ์คำศัพท์ที่ต้องการค้นหา...',
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
              future: _futureAll,
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

                // ✅ เก็บทั้ง raw + model เพื่อส่งไปหน้า detail
                final List<_VocabHit> results =
                    data
                        .map((map) => _VocabHit(map, Vocabulary.fromMap(map)))
                        .where((hit) {
                          if (searchQuery.isEmpty) return false;

                          final v = hit.vocab;
                          final word = v.headword.toLowerCase();
                          final trans = v.translationTH.toLowerCase();
                          final pos = v.pos.toLowerCase();
                          final cefr = v.cefr.toLowerCase();

                          return word.contains(searchQuery) ||
                              trans.contains(searchQuery) ||
                              pos.contains(searchQuery) ||
                              cefr.contains(searchQuery);
                        })
                        .toList()
                      ..sort(
                        (a, b) => a.vocab.headword.toLowerCase().compareTo(
                          b.vocab.headword.toLowerCase(),
                        ),
                      );

                if (searchQuery.isEmpty) {
                  return const Center(
                    child: Text('เริ่มพิมพ์เพื่อค้นหาคำศัพท์'),
                  );
                }

                if (results.isEmpty) {
                  return const Center(child: Text('ไม่พบคำศัพท์ที่ค้นหา'));
                }

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.grey.shade100,
                      child: Text(
                        "พบ: ${results.length} คำ",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final hit = results[index];
                          final vocab = hit.vocab;

                          final cefr = vocab.cefr.isEmpty ? "-" : vocab.cefr;
                          final headword = vocab.headword.isEmpty
                              ? "N/A"
                              : vocab.headword;
                          final pos = vocab.pos;
                          final transTh = vocab.translationTH;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    VocabDetailScreen
                                        .routeName, // หรือ '/vocab-detail'
                                    arguments: hit.raw,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.blueAccent
                                                .withOpacity(0.15),
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

                                          //  Text block
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        headword,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    if (pos.isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .grey
                                                              .shade100,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade200,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          pos,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors
                                                                .grey
                                                                .shade700,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  transTh.isEmpty
                                                      ? "-"
                                                      : transTh,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 6),

                                          // ✅ TTS (กัน tap ทะลุไป InkWell)
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () async {
                                              await _ttsService.speak(headword);
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(
                                                Icons.volume_up,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
