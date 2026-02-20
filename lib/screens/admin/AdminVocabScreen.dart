import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../models/vocab_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // อย่าลืม import
import 'package:google_generative_ai/google_generative_ai.dart';

class AdminVocabScreen extends StatefulWidget {
  const AdminVocabScreen({super.key});

  @override
  State<AdminVocabScreen> createState() => _AdminVocabScreenState();
}

class _AdminVocabScreenState extends State<AdminVocabScreen> {
  final _supabase = Supabase.instance.client;
  final String tableName = 'vocabularies';
  final TextEditingController _adminSearchController =
      TextEditingController(); // Controller
  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;
  bool _isAiLoading = false;
  String searchQuery = '';
  String selectedLetter = 'All';
  String selectedCEFR = 'All';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // ดึงข้อมูล
  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    const pageSize = 1000;
    int from = 0;
    final all = <Map<String, dynamic>>[];
    try {
      while (true) {
        final page = await _supabase
            .from(tableName)
            .select()
            .order('id', ascending: false)
            .range(from, from + pageSize - 1);
        final list = List<Map<String, dynamic>>.from(page);
        all.addAll(list);
        if (list.length < pageSize) break;
        from += pageSize;
      }
      if (!mounted) return;
      setState(() {
        _allData = all;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ฟังก์ชันเรียก AI (OpenAI) ---
  Future<Map<String, String>?> _fetchAiData(String word, String pos) async {
    // 1. ดึง API Key จาก .env
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint("Error: GEMINI_API_KEY not found in .env");
      return null;
    }

    // 2. ตั้งค่า Model (ใช้ gemini-1.5-flash จะเร็วและประหยัดกว่าสำหรับงาน fill ข้อมูล)
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // บังคับให้คืนค่าเป็น JSON
      ),
    );

    final prompt =
        """
  Provide vocabulary information for the word "$word" with part of speech "$pos".
  Return the result in JSON format only with the following keys:
  {
    "CEFR": "Level (A1, A2, B1, B2, C1, or C2)",
    "Reading_EN": "IPA or phonetic transcription",
    "Reading_TH": "Thai phonetic equivalent",
    "Translation_TH": "Thai translation",
    "Definition_TH": "short Thai definition",
    "Definition_EN": "short English definition",
    "Example_Sentence": "one clear English example sentence using the word",
    "TOEIC_Category": "common TOEIC topic like Office, Travel, Finance",
    "Synonyms": "2-3 synonyms separated by comma"
  }
  """;

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        // แปลง String JSON เป็น Map
        final Map<String, dynamic> decoded = jsonDecode(response.text!);

        // แปลงทุกอย่างเป็น Map<String, String> เพื่อส่งกลับไปเติมใน Controller
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      // แสดง SnackBar แจ้งเตือนแอดมินถ้า API มีปัญหา
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("AI Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return null;
  }

  @override
  void dispose() {
    _adminSearchController.dispose(); //  ล้าง Memory
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = searchQuery.toLowerCase().trim();

    var filteredDocs = _allData.where((d) {
      // 🚀 1. แปลงเป็น Model ก่อนใช้งาน
      final v = Vocabulary.fromMap(d);
      final id = (d['id'] ?? '').toString();

      final matchesSearch =
          q.isEmpty ||
          id.contains(q) ||
          v.headword.toLowerCase().contains(q) ||
          v.translationTH.toLowerCase().contains(q);

      final matchesLetter =
          selectedLetter == 'All' ||
          v.headword.toLowerCase().startsWith(selectedLetter.toLowerCase());

      final matchesCEFR =
          selectedCEFR == 'All' ||
          v.cefr.toUpperCase() == selectedCEFR.toUpperCase();

      return matchesSearch && matchesLetter && matchesCEFR;
    }).toList();

    // ✅ เรียง A-Z จริง (ไม่เพี้ยนเพราะตัวใหญ่/เล็ก)
    filteredDocs.sort((a, b) {
      final A = (a['headword'] ?? '').toString().toLowerCase();
      final B = (b['headword'] ?? '').toString().toLowerCase();
      return A.compareTo(B);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("จัดการคลังคำศัพท์"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          _buildSearchBar(),

          // ✅ ตัวนับจำนวนคำ
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Text(
              "พบทั้งหมด: ${filteredDocs.length} คำ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredDocs.isEmpty
                ? const Center(child: Text("ไม่พบข้อมูลคำศัพท์"))
                : ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) =>
                        _buildVocabCard(filteredDocs[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () => _showVocabForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- UI Widgets ---
  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.teal.shade50,
      child: Row(
        children: [
          _filterDropdown("A-Z", selectedLetter, [
            'All',
            ...List.generate(26, (i) => String.fromCharCode(65 + i)),
          ], (v) => setState(() => selectedLetter = v!)),
          const SizedBox(width: 8),
          _filterDropdown("CEFR", selectedCEFR, [
            'All',
            'A1',
            'A2',
            'B1',
            'B2',
            'C1',
            'C2',
          ], (v) => setState(() => selectedCEFR = v!)),
        ],
      ),
    );
  }

  Widget _filterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _adminSearchController, // 🚀 เพิ่ม controller
        onChanged: (v) => setState(() => searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: "ค้นหา ID, คำศัพท์ หรือ คำแปล...",
          prefixIcon: const Icon(Icons.search),
          // 🚀 เพิ่มปุ่มกากบาท
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _adminSearchController.clear();
                    setState(() => searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildVocabCard(Map<String, dynamic> data) {
    final v = Vocabulary.fromMap(data); // 🚀 ใช้ Model

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.1),
          child: Text(
            v.cefr.isEmpty ? "-" : v.cefr,
            style: const TextStyle(
              color: Colors.teal,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              v.headword,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (v.pos.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '(${v.pos})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          "แปล: ${v.translationTH}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showVocabForm(existingData: data),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(data['id']),
            ),
          ],
        ),
      ),
    );
  }

  // --- ฟอร์ม Add/Edit ---
  void _showVocabForm({Map<String, dynamic>? existingData}) {
    Vocabulary? v;
    if (existingData != null) {
      v = Vocabulary.fromMap(existingData);
    }

    final headwordC = TextEditingController(text: v?.headword);
    final posC = TextEditingController(text: v?.pos);
    final cefrC = TextEditingController(text: v?.cefr);
    final readingEnC = TextEditingController(text: v?.readingEn);
    final readingThC = TextEditingController(text: v?.readingTh);
    final transThC = TextEditingController(text: v?.translationTH);
    final defThC = TextEditingController(text: v?.definitionTH);
    final defEnC = TextEditingController(text: v?.definitionEN);
    final exampleC = TextEditingController(text: v?.exampleSentence);
    final categoryC = TextEditingController(text: v?.toeicCategory);
    final synonymsC = TextEditingController(text: v?.synonyms);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        // ใช้ StatefulBuilder เพื่อให้ปุ่ม AI กดแล้วหมุนได้
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existingData == null
                      ? "เพิ่มคำศัพท์ใหม่"
                      : "แก้ไขคำศัพท์ ID: ${existingData['id']}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),

                // คำศัพท์ + ปุ่ม AI
                Row(
                  crossAxisAlignment: CrossAxisAlignment
                      .end, // ให้ปุ่มอยู่ระดับเดียวกับบรรทัดล่างของช่องพิมพ์
                  children: [
                    Expanded(
                      child: TextField(
                        controller: headwordC,
                        onChanged: (val) => setModalState(
                          () {},
                        ), // รีเฟรช Modal เพื่อเช็คเงื่อนไขปุ่ม
                        decoration: const InputDecoration(
                          labelText: "คำศัพท์ (Headword) *",
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ใช้ Builder เพื่อเช็คสถานะจาก TextController ณ เวลาปัจจุบัน
                    Builder(
                      builder: (context) {
                        final bool isReady =
                            headwordC.text.trim().isNotEmpty &&
                            posC.text.trim().isNotEmpty;

                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isReady
                                ? Colors.purple.shade50
                                : Colors.grey.shade200,
                            foregroundColor: isReady
                                ? Colors.purple
                                : Colors.grey,
                            elevation: isReady ? 2 : 0,
                          ),
                          onPressed: (_isAiLoading || !isReady)
                              ? null
                              : () async {
                                  setModalState(() => _isAiLoading = true);
                                  try {
                                    final ai = await _fetchAiData(
                                      headwordC.text.trim(),
                                      posC.text.trim(),
                                    );
                                    if (ai != null) {
                                      setModalState(() {
                                        cefrC.text = ai['CEFR'] ?? '';
                                        readingEnC.text =
                                            ai['Reading_EN'] ?? '';
                                        readingThC.text =
                                            ai['Reading_TH'] ?? '';
                                        transThC.text =
                                            ai['Translation_TH'] ?? '';
                                        defThC.text = ai['Definition_TH'] ?? '';
                                        defEnC.text = ai['Definition_EN'] ?? '';
                                        exampleC.text =
                                            ai['Example_Sentence'] ?? '';
                                        categoryC.text =
                                            ai['TOEIC_Category'] ?? '';
                                        synonymsC.text = ai['Synonyms'] ?? '';
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint("AI Error: $e");
                                  } finally {
                                    setModalState(() => _isAiLoading = false);
                                  }
                                },
                          icon: _isAiLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.purple,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text("AI Fill"),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: posC,
                        // เพิ่ม onChanged เพื่อให้ปุ่ม AI รู้ตัวเวลาพิมพ์
                        onChanged: (val) => setModalState(
                          () {},
                        ), // รีเฟรช Modal เพื่อเช็คเงื่อนไขปุ่ม
                        decoration: const InputDecoration(
                          labelText: "POS (n., v.) *",
                          hintText: "เช่น v.",
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: cefrC,
                        decoration: const InputDecoration(
                          labelText: "CEFR (A1-C2)",
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: readingEnC,
                        decoration: const InputDecoration(
                          labelText: "Reading (EN)",
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: readingThC,
                        decoration: const InputDecoration(
                          labelText: "คำอ่าน (ไทย)",
                        ),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: transThC,
                  decoration: const InputDecoration(labelText: "คำแปลไทย"),
                ),
                TextField(
                  controller: defThC,
                  decoration: const InputDecoration(
                    labelText: "คำจำกัดความ (ไทย)",
                  ),
                ),
                TextField(
                  controller: defEnC,
                  decoration: const InputDecoration(
                    labelText: "คำจำกัดความ (Eng)",
                  ),
                ),
                TextField(
                  controller: exampleC,
                  decoration: const InputDecoration(
                    labelText: "ตัวอย่างประโยค",
                  ),
                ),
                TextField(
                  controller: categoryC,
                  decoration: const InputDecoration(
                    labelText: "หมวดหมู่ TOEIC",
                  ),
                ),
                TextField(
                  controller: synonymsC,
                  decoration: const InputDecoration(
                    labelText: "คำพ้องความหมาย",
                  ),
                ),

                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.teal,
                  ),
                  onPressed: () async {
                    final h = headwordC.text.trim();
                    final p = posC.text.trim();
                    if (h.isEmpty || p.isEmpty) return;

                    // 1. เช็คคำซ้ำก่อนบันทึก (Pre-check)
                    // ถ้าเป็นการเพิ่มใหม่ (existingData == null) ให้เช็คว่ามี headword + pos นี้หรือยัง
                    if (existingData == null) {
                      final dup = await _supabase
                          .from(tableName)
                          .select('id')
                          .eq('headword', h)
                          .eq('pos', p)
                          .maybeSingle();

                      if (dup != null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("❌ '$h ($p)' มีอยู่ในระบบแล้ว!"),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                        return; // หยุดการทำงาน
                      }
                    }

                    // 2. เตรียมข้อมูล (Payload)
                    final payload = {
                      if (existingData != null)
                        'id':
                            existingData['id'], // สำคัญ: ต้องมี id เพื่อให้มันแก้ไขบรรทัดเดิม
                      'headword': h,
                      'pos': p,
                      'CEFR': cefrC.text.trim().toUpperCase(),
                      'Reading_EN': readingEnC.text.trim(),
                      'Reading_TH': readingThC.text.trim(),
                      'Translation_TH': transThC.text.trim(),
                      'Definition_TH': defThC.text.trim(),
                      'Definition_EN': defEnC.text.trim(),
                      'Example_Sentence': exampleC.text.trim(),
                      'TOEIC_Category': categoryC.text.trim(),
                      'Synonyms': synonymsC.text.trim(),
                      'updated_at': DateTime.now().toIso8601String(),
                    };

                    // 3. บันทึกลง Database
                    try {
                      await _supabase
                          .from(tableName)
                          .upsert(
                            payload,
                            onConflict: 'headword,pos',
                          ); // ใช้คอลัมน์ที่เป็นตัวตัดสินความซ้ำ

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("✅ บันทึกข้อมูลสำเร็จ"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      _refreshData();
                    } catch (e) {
                      debugPrint("Save error: $e");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("❌ บันทึกไม่สำเร็จ: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    "บันทึกข้อมูล",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการลบ?"),
        content: Text("คุณต้องการลบคำศัพท์รหัส $id ใช่หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ยกเลิก"),
          ),
          TextButton(
            onPressed: () async {
              await _supabase.from(tableName).delete().eq('id', id);
              if (mounted) Navigator.pop(context);
              _refreshData();
            },
            child: const Text("ลบ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
