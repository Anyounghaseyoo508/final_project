import 'package:flutter/material.dart';
import '../../services/tts_service.dart';

class VocabDetailScreen extends StatefulWidget {
  static const routeName = '/vocab-detail'; // ✅ ชื่อ route

  const VocabDetailScreen({super.key});

  @override
  State<VocabDetailScreen> createState() => _VocabDetailScreenState();
}

class _VocabDetailScreenState extends State<VocabDetailScreen> {
  final TTSService _ttsService = TTSService();

  String _s(dynamic v) => (v ?? '').toString();

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(value.isEmpty ? "-" : value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ttsService.init();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ รับ data จาก route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    final m = (args is Map<String, dynamic>) ? args : <String, dynamic>{};

    final headword = _s(m['headword']);
    final cefr = _s(m['CEFR']);
    final pos = _s(m['POS']);
    final transTh = _s(m['Translation_TH']);
    final defTh = _s(m['Definition_TH']);
    final defEn = _s(m['Definition_EN']);
    final example = _s(m['Example_Sentence']);
    final category = _s(m['TOEIC_Category']);
    final synonyms = _s(m['Synonyms']);

    return Scaffold(
      appBar: AppBar(
        title: Text(headword.isEmpty ? "รายละเอียดคำศัพท์" : headword),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _ttsService.speak(headword),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    cefr.isEmpty ? "-" : cefr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headword.isEmpty ? "N/A" : headword,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pos.isEmpty ? "-" : pos,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        transTh.isEmpty ? "-" : transTh,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _info("Definition_TH", defTh),
          _info("Definition_EN", defEn),
          _info("Example_Sentence", example),
          _info("TOEIC_Category", category),
          _info("Synonyms", synonyms),
        ],
      ),
    );
  }
}
