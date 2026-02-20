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

class _VocabCategoryDetailScreenState extends State<VocabCategoryDetailScreen> {
  String searchQuery = "";
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _future;

  // แก้ไขใน vocab_category_detail_screen.dart ฟังก์ชัน _fetchVocabs
  Future<List<Map<String, dynamic>>> _fetchVocabs() async {
    try {
      // 🚀 กรองจาก Database เลย และดึงมาเฉพาะระดับที่เลือก
      final response = await _supabase
          .from('vocabularies')
          .select()
          .ilike('CEFR', widget.categoryLevel.trim()) // กรองระดับภาษา
          .order('headword', ascending: true);
      /*.range(
            0,
            3000,
          ); // ดึงมา 3000 คำแรกของระดับนั้น (สามารถเพิ่มระบบ Load More ได้ภายหลัง)*/

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error: $e");
      return [];
    }
  }

  int _totalCount = 0;

  Future<void> _getTotalCount() async {
    try {
      // 🚀 วิธีเขียนแบบใหม่ของ Supabase v2.x
      final response = await _supabase
          .from('vocabularies')
          .select()
          .ilike('CEFR', widget.categoryLevel.trim())
          .count(CountOption.exact); // ✅ ใช้ .count() ต่อท้ายแบบนี้

      setState(() {
        // สำหรับ .count() ค่าที่คืนกลับมาจะอยู่ที่ response.count
        _totalCount = response.count;
      });
    } catch (e) {
      debugPrint("Error counting rows: $e");
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
      appBar: AppBar(
        title: Text(widget.categoryTitle),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ส่วนค้นหาภายในหมวดหมู่
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ค้นหาในระดับ ${widget.categoryLevel}...',
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                  );
                }

                final List<Map<String, dynamic>> rawData = snapshot.data ?? [];

                if (rawData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text('ไม่พบคำศัพท์ในระดับ ${widget.categoryLevel}'),
                      ],
                    ),
                  );
                }

                // ✅ 1. การกรองข้อมูล (Filter)
                final filteredItems = rawData.where((item) {
                  final v = Vocabulary.fromMap(item);
                  if (searchQuery.isEmpty) return true;
                  return v.headword.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ||
                      v.translationTH.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      );
                }).toList();

                return Column(
                  children: [
                    // ✅ 2. เพิ่มส่วนแสดงสรุปจำนวนคำ (Summary Bar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.blue.shade100),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ทั้งหมด $_totalCount คำ", // จำนวนทั้งหมดใน DB ของหมวดนี้
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (searchQuery.isNotEmpty)
                            Text(
                              "ค้นพบ ${filteredItems.length} คำ", // จำนวนที่กรองได้จากช่องค้นหา
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ✅ 3. ส่วนแสดงรายการคำศัพท์
                    Expanded(
                      child: filteredItems.isEmpty && searchQuery.isNotEmpty
                          ? const Center(
                              child: Text('ไม่พบคำศัพท์ที่ตรงกับเงื่อนไขค้นหา'),
                            )
                          : ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              padding: const EdgeInsets.all(12),
                              itemBuilder: (context, index) {
                                final itemData = filteredItems[index];
                                final v = Vocabulary.fromMap(itemData);

                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        VocabDetailScreen.routeName,
                                        arguments: itemData,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.blueAccent
                                                .withOpacity(0.1),
                                            child: Text(
                                              v.cefr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  v.headword,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  v.translationTH,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.volume_up,
                                              color: Colors.blueAccent,
                                            ),
                                            onPressed: () =>
                                                _ttsService.speak(v.headword),
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
