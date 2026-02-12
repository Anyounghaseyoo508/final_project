import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVocabScreen extends StatefulWidget {
  const AdminVocabScreen({super.key});

  @override
  State<AdminVocabScreen> createState() => _AdminVocabScreenState();
}

class _AdminVocabScreenState extends State<AdminVocabScreen> {
  final _supabase = Supabase.instance.client;
  final String tableName = 'vocabularies';

  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;

  String searchQuery = '';
  String selectedLetter = 'All';
  String selectedCEFR = 'All';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // ✅ ดึงข้อมูลแบบ paginate ให้ครบจริง (กันติด max rows 1000)
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
            .order('id', ascending: false) // ดึงแบบล่าสุดก่อน (เร็ว + ชัวร์)
            .range(from, from + pageSize - 1);

        final list = List<Map<String, dynamic>>.from(page);
        all.addAll(list);

        // ถ้าได้น้อยกว่า pageSize แปลว่าหมดแล้ว
        if (list.length < pageSize) break;
        from += pageSize;
      }

      if (!mounted) return;
      setState(() {
        _allData = all;
        _isLoading = false;
      });

      debugPrint("ดึงข้อมูลสำเร็จ: ${_allData.length} คำ");
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("เกิดข้อผิดพลาด: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Filter + Search ---
    final q = searchQuery.toLowerCase().trim();

    var filteredDocs = _allData.where((d) {
      final id = (d['id'] ?? '').toString().toLowerCase();
      final headwordRaw = (d['headword'] ?? '').toString();
      final headword = headwordRaw.toLowerCase();
      final transTH = (d['Translation_TH'] ?? '').toString().toLowerCase();
      final cefr = (d['CEFR'] ?? '').toString().toUpperCase();

      final matchesSearch =
          q.isEmpty || id.contains(q) || headword.contains(q) || transTH.contains(q);

      final matchesLetter =
          selectedLetter == 'All' || headword.startsWith(selectedLetter.toLowerCase());

      final matchesCEFR =
          selectedCEFR == 'All' || cefr == selectedCEFR.toUpperCase();

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
        onChanged: (v) => setState(() => searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: "ค้นหา ID, คำศัพท์ หรือ คำแปล...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildVocabCard(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal,
          child: Text(
            data['id'].toString(),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
        title: Text(
          data['headword'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "${data['POS'] ?? ''} | แปล: ${data['Translation_TH'] ?? ''}",
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
    final headwordC = TextEditingController(text: existingData?['headword']);
    final posC = TextEditingController(text: existingData?['POS']);
    final cefrC = TextEditingController(text: existingData?['CEFR']);
    final transThC = TextEditingController(text: existingData?['Translation_TH']);
    final defThC = TextEditingController(text: existingData?['Definition_TH']);
    final defEnC = TextEditingController(text: existingData?['Definition_EN']);
    final exampleC = TextEditingController(text: existingData?['Example_Sentence']);
    final categoryC = TextEditingController(text: existingData?['TOEIC_Category']);
    final synonymsC = TextEditingController(text: existingData?['Synonyms']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              TextField(
                controller: headwordC,
                decoration: const InputDecoration(labelText: "คำศัพท์ (Headword) *"),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: posC,
                      decoration: const InputDecoration(labelText: "POS (n., v., adj.)"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cefrC,
                      decoration: const InputDecoration(labelText: "CEFR (A1-C2)"),
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
                decoration: const InputDecoration(labelText: "คำจำกัดความ (ไทย)"),
              ),
              TextField(
                controller: defEnC,
                decoration: const InputDecoration(labelText: "คำจำกัดความ (Eng)"),
              ),
              TextField(
                controller: exampleC,
                decoration: const InputDecoration(labelText: "ตัวอย่างประโยค"),
              ),
              TextField(
                controller: categoryC,
                decoration: const InputDecoration(labelText: "หมวดหมู่ TOEIC"),
              ),
              TextField(
                controller: synonymsC,
                decoration: const InputDecoration(labelText: "คำพ้องความหมาย (Synonyms)"),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (headwordC.text.trim().isEmpty) return;

                  final payload = {
                    if (existingData != null) 'id': existingData['id'],
                    'headword': headwordC.text.trim(),
                    'POS': posC.text.trim(),
                    'CEFR': cefrC.text.trim().toUpperCase(),
                    'Translation_TH': transThC.text.trim(),
                    'Definition_TH': defThC.text.trim(),
                    'Definition_EN': defEnC.text.trim(),
                    'Example_Sentence': exampleC.text.trim(),
                    'TOEIC_Category': categoryC.text.trim(),
                    'Synonyms': synonymsC.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  };

                  try {
                    await _supabase.from(tableName).upsert(payload);
                    if (mounted) Navigator.pop(context);
                    _refreshData();
                  } catch (e) {
                    debugPrint("Save error: $e");
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
