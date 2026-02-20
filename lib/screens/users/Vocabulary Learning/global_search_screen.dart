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

// คลาสสำหรับเก็บข้อมูลที่ดึงมาจาก Database เพื่อส่งต่อไปหน้า Detail
class _VocabHit {
  final Map<String, dynamic> raw; // ข้อมูลดิบ (JSON/Map) จาก Supabase
  final Vocabulary vocab;        // ข้อมูลที่ถูกแปลงเป็น Model แล้ว
  _VocabHit(this.raw, this.vocab);
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  String searchQuery = "";
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController(); //เพิ่ม controller
  
  // รายการผลลัพธ์การค้นหา
  List<_VocabHit> _searchResults = [];
  bool _isLoading = false; // สถานะการโหลด
  String? _error;          // เก็บข้อความเมื่อเกิด Error

  @override
  void initState() {
    super.initState();
    _ttsService.init();
  }

  //  ฟังก์ชันค้นหาแบบ Server-side (ค้นหาจาก Database โดยตรง)
  Future<void> _performSearch(String query) async {
    // ถ้าช่องค้นหาว่าง ให้ล้างรายการผลลัพธ์
    if (query.trim().isEmpty) {
      setState(() {
        searchQuery = "";
        _searchResults = [];
      });
      return;
    }

    setState(() {
      searchQuery = query;
      _isLoading = true; // แสดง Loading Spinner
      _error = null;
    });

    try {
      // 🚀 ส่งคำค้นหาไปที่ Supabase
      final response = await _supabase
          .from('vocabularies')
          .select()
          // ใช้ ilike เพื่อค้นหาแบบไม่สนใจตัวพิมพ์เล็ก-ใหญ่
          // ค้นหาทั้งคำศัพท์ (headword) หรือคำแปล (Translation_TH)
          .or('headword.ilike.%$query%,Translation_TH.ilike.%$query%') 
          .limit(50); // ดึงมาแค่ 50 รายการที่ตรงที่สุด เพื่อความเร็วและประหยัดเน็ต

      setState(() {
        _searchResults = (response as List)
            .map((map) => _VocabHit(map, Vocabulary.fromMap(map)))
            .toList();
        _isLoading = false; // ปิด Loading
      });
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() {
        _error = "เกิดข้อผิดพลาดในการเชื่อมต่อฐานข้อมูล";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    //  ล้าง Memory เมื่อปิดหน้านี้
    _searchController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาจากคำศัพท์'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ส่วนช่องกรอกคำค้นหา
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController, //  ผูกคอนโทรลเลอร์
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'พิมพ์คำศัพท์ หรือความหมายภาษาไทย...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear), 
                      onPressed: () {
                        setState(() {
                          _searchController.clear(); // สั่งล้างข้อความในช่องพิมพ์
                          searchQuery = "";
                          _searchResults = [];
                        });
                      }) 
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              // เมื่อมีการพิมพ์ ให้เรียกฟังก์ชันค้นหาไปยัง Database
              onChanged: (value) => _performSearch(value),
            ),
          ),

          // ส่วนแสดงผลลัพธ์
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 1. แสดงตัวหมุนขณะกำลังดึงข้อมูลจาก Server
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. แสดง Error หากดึงข้อมูลไม่ได้
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    // 3. หน้าว่างตอนที่ยังไม่ได้เริ่มพิมพ์ค้นหา
    if (searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.manage_search, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('พิมพ์เพื่อค้นหาคำศัพท์ในฐานข้อมูล',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // 4. แสดงกรณีหาคำนั้นไม่เจอในหมื่นคำ
    if (_searchResults.isEmpty) {
      return const Center(child: Text('ไม่พบคำศัพท์ที่ตรงกับเงื่อนไข'));
    }

    // 5. แสดงรายการคำศัพท์ที่ค้นหาเจอ
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blueAccent.withOpacity(0.05),
          child: Text(
            "พบที่ใกล้เคียง: ${_searchResults.length} รายการ (แสดงผลลัพธ์ที่ตรงที่สุด)",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final hit = _searchResults[index];
              return _buildVocabCard(hit);
            },
          ),
        ),
      ],
    );
  }

  // ส่วนของการสร้าง Card แสดงคำศัพท์แต่ละคำ
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
          onTap: () {
            // ส่งข้อมูลกลับไปหน้า Detail โดยส่ง Map ตัวเต็ม (hit.raw)
            Navigator.pushNamed(
              context,
              VocabDetailScreen.routeName,
              arguments: hit.raw, 
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // แสดงระดับภาษา (A1-C2)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    vocab.cefr.isEmpty ? "-" : vocab.cefr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // ข้อมูลคำศัพท์และคำแปล
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
                // ปุ่มกดฟังเสียงอ่าน
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