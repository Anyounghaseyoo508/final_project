import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ เพิ่มสำหรับดึงข้อมูลใหม่
import '../../../services/tts_service.dart';

class VocabDetailScreen extends StatefulWidget {
  static const routeName = '/vocab-detail';

  const VocabDetailScreen({super.key});

  @override
  State<VocabDetailScreen> createState() => _VocabDetailScreenState();
}

class _VocabDetailScreenState extends State<VocabDetailScreen> {
  final TTSService _ttsService = TTSService();
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _currentData; // ✅ เก็บข้อมูลปัจจุบันที่แสดงผล
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
    // ✅ ใช้ Future.microtask เพื่อดึง arguments หลังจาก build context พร้อม
    Future.microtask(() => _handleArguments());
  }

  // ✅ จัดการดึงข้อมูลไม่ว่าจะส่งมาเป็น Map หรือแค่ String (คำศัพท์)
  void _handleArguments() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() => _currentData = args);
      _checkBookmarkStatus(args['id']); // เช็คสถานะบันทึก
    } else if (args is String) {
      _loadVocabByHeadword(args);
    }
  }

  // ✅ ฟังก์ชันเช็คสถานะการบันทึกจาก Database
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

  // ✅ ฟังก์ชัน กดบันทึก/ยกเลิกบันทึก
  Future<void> _toggleBookmark() async {
    final user = _supabase.auth.currentUser;
    final vocabId = _currentData?['id'];

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเข้าสู่ระบบเพื่อบันทึก")),
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
      } else {
        await _supabase.from('bookmarks').insert({
          'user_id': user.id,
          'vocab_id': vocabId,
        });
      }
      setState(() => _isBookmarked = !_isBookmarked);
    } catch (e) {
      debugPrint("Bookmark Error: $e");
    }
  }

  // ✅ ฟังก์ชันดึงข้อมูลใหม่เมื่อกดที่ Synonym
  /*Future<void> _loadVocabByHeadword(String word) async {
    final cleanWord = word.trim(); // ตัดช่องว่างออกให้หมด
    if (cleanWord.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('vocabularies')
          .select()
          .ilike(
            'headword',
            cleanWord,
          ) // ✅ ใช้ ilike แทน eq เพื่อป้องกัน Case-sensitive
          .maybeSingle();

      if (data != null) {
        setState(() {
          _currentData = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่พบข้อมูลคำว่า "$cleanWord"')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error loading synonym: $e");
      setState(() => _isLoading = false);
    }
  }*/

  // ฟังก์ชันดึงข้อมูลใหม่เมื่อกดที่ Synonym
  Future<void> _loadVocabByHeadword(String word) async {
    final cleanWord = word
        .trim(); // 1. นำ word ที่รับเข้ามา มาตัดช่องว่างออก แล้วเก็บไว้ในชื่อ cleanWord
    if (cleanWord.isEmpty)
      return; // 2. เช็คว่าหลังจากตัดช่องว่างแล้ว มันกลายเป็นคำว่างเปล่าไหม

    // 3. ส่ง cleanWord ที่สะอาดแล้ว ไปให้ Database ค้นหา
    setState(() => _isLoading = true);
    try {
      // 🚀 แก้ไขจาก .maybeSingle() เป็น .select().ilike().limit(1)
      final response = await _supabase
          .from('vocabularies')
          .select()
          .ilike(
            'headword',
            cleanWord,
          ) //ค้นหาข้อมูลที่มี "ความคล้ายคลึง" โดยมีคุณสมบัติพิเศษคือ ไม่สนใจตัวพิมพ์เล็ก-ใหญ่ (Case-Insensitive)
          .limit(1); //  ดึงมาแค่ตัวเดียวพอ ถ้าเจอซ้ำให้เอาตัวแรก

      if ((response as List).isNotEmpty) {
        //response != null && (response as List).isNotEmpty
        setState(() {
          _currentData = response[0]; //  ใช้ตัวแรกที่เจอ
          _isLoading = false;
        });
        _checkBookmarkStatus(
          _currentData!['id'],
        ); // เช็ค Bookmark หลังโหลดข้อมูลใหม่
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่พบข้อมูลคำว่า "$cleanWord"')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error loading synonym: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_currentData == null)
      return const Scaffold(body: Center(child: Text("ไม่พบข้อมูล")));

    final m = _currentData!;
    final headword = _s(m['headword']);
    final cefr = _s(m['CEFR']);
    final pos = _s(m['pos']);
    final readingEn = _s(m['Reading_EN']);
    final readingTh = _s(m['Reading_TH']);
    final transTh = _s(m['Translation_TH']);
    final defTh = _s(m['Definition_TH']);
    final defEn = _s(m['Definition_EN']);
    final example = _s(m['Example_Sentence']);
    final category = _s(m['TOEIC_Category']);
    final synonymsRaw = _s(m['Synonyms']);
    final synList = _formatSynonyms(synonymsRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text(headword),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          // ✅ เพิ่มปุ่มเล่นเสียงบน AppBar (ทางเลือกที่ 1) หรือใส่ใน Card ก็ได้
          /*IconButton(
            onPressed: () => _ttsService.speak(headword),
            icon: const Icon(Icons.volume_up),
          ),*/
          // เพิ่มปุ่ม Bookmark บน AppBar 
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
          // --- Header Card --- (ใช้โค้ดเดิมของคุณ)
          _buildHeaderCard(
            headword,
            cefr,
            readingEn,
            readingTh,
            pos,
            transTh,
            _isBookmarked,
            _toggleBookmark,
          ),

          const SizedBox(height: 10),
          _info("ความหมาย (ภาษาไทย)", defTh),
          _info("Definition (English)", defEn),
          _info("ตัวอย่างประโยค", example),
          _info("หมวดหมู่ TOEIC", category),

          // --- Synonyms Chips Section (จุดที่แก้ไข) ---
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              "คำเหมือน (Synonyms) - คลิกเพื่อดูรายละเอียด",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blueAccent,
              ),
            ),
          ),
          synList.isEmpty
              ? const Text("-")
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: synList.map((syn) {
                    final cleanSyn = syn
                        .trim(); // ✅ มั่นใจว่าคำที่คลิกไม่มีช่องว่างปน
                    return ActionChip(
                      label: Text(cleanSyn),
                      onPressed: () {
                        // หากต้องการให้กดย้อนกลับมาคำเดิมได้ ให้ใช้ pushNamed
                        // หากต้องการให้เปลี่ยนคำในหน้าเดิมไปเลย ให้ใช้ pushReplacementNamed
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

  // แยก Widget Header ออกมาเพื่อความสะอาด
  Widget _buildHeaderCard(
    String headword,
    String cefr,
    String readingEn,
    String readingTh,
    String pos,
    String transTh,
    bool isBookmarked, // รับค่าสถานะผ่าน parameter
    VoidCallback onBookmark, // รับฟังก์ชันผ่าน parameter
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
          // --- แถวบน: เสียง + คำศัพท์ + ปุ่มบันทึก + CEFR ---
          Row(
            children: [
              Expanded(
                // คำศัพท์
                child: Text(
                  headword,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),


              // ป้าย CEFR
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              // 🔊 ปุ่มเล่นเสียง
              IconButton(
                onPressed: () => _ttsService.speak(headword),
                icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              //  ปุ่ม Bookmark (ใช้ค่าจาก parameter)
              /*IconButton(
                onPressed: onBookmark,
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                ),
                color: isBookmarked ? Colors.orange : Colors.grey,
              ),*/
            ],
          ),

          const SizedBox(height: 8),

          // --- คำอ่าน ---
          Text(
            "$readingEn  ($readingTh)",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 12),

          // --- Part of Speech (POS) ---
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

          // --- คำแปลภาษาไทย ---
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
            value.isEmpty ? "-" : value,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}
