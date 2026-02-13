import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class AdminAddQuestionScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const AdminAddQuestionScreen({super.key, this.editData});

  @override
  State<AdminAddQuestionScreen> createState() => _AdminAddQuestionScreenState();
}

class _AdminAddQuestionScreenState extends State<AdminAddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isGeneratingAI = false;

  late TextEditingController _testId,
      _part,
      _qNo,
      _qText,
      _transcript,
      _optA,
      _optB,
      _optC,
      _optD,
      _explanation,
      _category,
      _passageGroupId,
      _audioUrl,
      _imageUrl,
      _startTime,
      _endTime;

  String _selectedCorrectAnswer = 'A';

  @override
  void initState() {
    super.initState();
    _testId = TextEditingController(
      text: widget.editData?['test_id']?.toString() ?? "1",
    );
    _part = TextEditingController(
      text: widget.editData?['part']?.toString() ?? "1",
    );
    _qNo = TextEditingController(
      text: widget.editData?['question_no']?.toString() ?? "",
    );
    _qText = TextEditingController(
      text: widget.editData?['question_text'] ?? "",
    );
    _category = TextEditingController(
      text: widget.editData?['category']?.toString() ?? "",
    );
    _transcript = TextEditingController(
      text: widget.editData?['transcript'] ?? "",
    );
    _optA = TextEditingController(text: widget.editData?['option_a'] ?? "");
    _optB = TextEditingController(text: widget.editData?['option_b'] ?? "");
    _optC = TextEditingController(text: widget.editData?['option_c'] ?? "");
    _optD = TextEditingController(text: widget.editData?['option_d'] ?? "");
    _explanation = TextEditingController(
      text: widget.editData?['explanation'] ?? "",
    );
    _passageGroupId = TextEditingController(
      text: widget.editData?['passage_group_id'] ?? "",
    );
    _audioUrl = TextEditingController(
      text: widget.editData?['audio_url'] ?? "",
    );
    _imageUrl = TextEditingController(
      text: widget.editData?['image_url'] ?? "",
    ); // ดึงข้อมูล image_url เดิม
    _startTime = TextEditingController(
      text: widget.editData?['start_time']?.toString() ?? "0",
    );
    _endTime = TextEditingController(
      text: widget.editData?['end_time']?.toString() ?? "0",
    );
    _selectedCorrectAnswer = widget.editData?['correct_answer'] ?? 'A';
  }

  // --- 1. ฟังก์ชันสแกนรูปภาพ (OCR) เพื่อเอาข้อความลง Transcript ---
  Future<void> _aiScanAndFill() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return;

    setState(() => _isGeneratingAI = true);

    try {
      List<String> imageUrls = [];
      int partNum = int.tryParse(_part.text) ?? 0;

      // --- ส่วนที่ 1: ดึงรูปภาพ ---
      // ถ้าในช่อง URL ว่าง แต่มี Group ID (ใช้ได้ทั้ง Part 6 และ 7)
      if (_imageUrl.text.isEmpty && _passageGroupId.text.isNotEmpty) {
        final response = await _supabase
            .from('passages')
            .select('image_url')
            .eq('passage_group_id', _passageGroupId.text)
            .order('sequence', ascending: true);

        if (response.isNotEmpty) { // if (response != null && response.isNotEmpty)
          imageUrls = List<String>.from(
            response.map((item) => item['image_url']),
          );
          _imageUrl.text = imageUrls.first;
        }
      } else if (_imageUrl.text.isNotEmpty) {
        imageUrls.add(_imageUrl.text);
      }

      if (imageUrls.isEmpty) {
        _showSnackBar(
          "⚠️ ไม่พบรูปภาพ (กรุณาใส่ Image URL หรือ Passage Group ID)",
        );
        return;
      }

      // --- ส่วนที่ 2: เรียก Gemini OCR ---
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // แนะนำ 1.5-flash เพราะเสถียรกว่าในงาน OCR
        apiKey: apiKey,
        generationConfig: GenerationConfig(temperature: 0.1),
        // เพิ่มส่วนนี้เข้าไปครับ
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );
      final List<DataPart> imageParts = [];
      for (String url in imageUrls) {
        final imgRes = await http.get(Uri.parse(url));
        imageParts.add(DataPart('image/jpeg', imgRes.bodyBytes));
      }

      // ปรับ Prompt ให้ฉลาดขึ้นสำหรับ Part 6 (Text Completion)
      final prompt = '''
As an educational assistant, please digitize the text from this image for a practice database.
- Please transcribe the text exactly as it appears.
- If the content belongs to a standardized test, format the output as a "reconstructed study material" to ensure accessibility.
- Keep all original numbers, blanks (e.g., [131]), and punctuation.
- Output ONLY the plain text from the image.
''';

      final content = [
        Content.multi([TextPart(prompt), ...imageParts]),
      ];

      final aiResponse = await model.generateContent(content);

      setState(() {
        _transcript.text = aiResponse.text ?? "";

        // ตั้งค่าโจทย์เริ่มต้นตามประเภท Part
        if (partNum == 6 && _qText.text.isEmpty) {
          _qText.text =
              "Select the best word or phrase to complete the sentence.";
        } else if (partNum == 7 && _qText.text.isEmpty) {
          _qText.text = "Refer to the text to answer the question.";
        }
      });

      _showSnackBar("✅ สแกน ${imageUrls.length} รูปสำเร็จ (Part $partNum)");
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() => _isGeneratingAI = false);
    }
  }

  // --- 2. ฟังก์ชันเฉลย (ปรับปรุงให้ใช้ข้อมูลจาก Transcript ร่วมด้วย) ---
  Future<void> _generateExplanationWithAI() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _showSnackBar("❌ ไม่พบ API KEY");
      return;
    }

    int partNum = int.tryParse(_part.text) ?? 0;
    bool isListeningPart = partNum >= 1 && partNum <= 4;
    //bool isGrammarPart = partNum == 5;
    bool isReadingPart = partNum == 6 || partNum == 7;

    if ((isListeningPart || isReadingPart) && _transcript.text.trim().isEmpty) {
      _showSnackBar("⚠️ พาร์ทนี้ต้องใช้เนื้อหาจาก Transcript เพื่อวิเคราะห์");
      return;
    }

    if (_qText.text.isEmpty && !isReadingPart) {
      _showSnackBar("⚠️ กรุณากรอกโจทย์ก่อน");
      return;
    }

    setState(() => _isGeneratingAI = true);

    try {
      final model = GenerativeModel(
        model:
            'gemini-2.5-flash', // ใช้ตัว 1.5 Flash เพื่อความเสถียรในบทความยาวๆ
        apiKey: apiKey,
      );

      final prompt =
          """
คุณคือติวเตอร์ TOEIC ผู้เชี่ยวชาญระดับ 990 คะแนน หน้าที่ของคุณคือวิเคราะห์ข้อสอบและจัดหมวดหมู่ให้ถูกต้อง 100%

[กฎลำดับความสำคัญ (Strict Priority Rules)]
1. หากเป็น Part 1 (Listening - Photograph): ต้องตอบ "Graphic Content" เท่านั้น แม้ประโยคจะเป็น Passive Voice ก็ตาม
2. หากเป็น Part 3, 4, 7 และคำถามต้องดูข้อมูลจากรูปภาพ/ตาราง/แผนผังประกอบ: ต้องตอบ "Graphic Content"
3. หากเป็น Part 3, 4, 7 และถามหาวัตถุประสงค์หลัก/หัวข้อ (Purpose, Why, Topic): ตอบ "Main Idea"
4. หากเป็น Part 2, 3, 4, 7 และถามข้อมูลที่ระบุในเนื้อหา (When, Where, Who, How): ตอบ "Detail"
5. หากเป็น Part 3, 4, 7 และต้องตีความ (Implied, Likely, Suggested): ตอบ "Inference"
6. หากเป็น Part 5, 6 ให้พิจารณาหมวด Grammar & Vocabulary ตามลำดับ: [Part of Speech, Tense, Passive Voice, Subject-Verb Agreement, Preposition & Conjunction, Comparison, Pronoun, Participle, Collocation, Vocabulary]

[ข้อมูลสำหรับวิเคราะห์]
- Part: ${_part.text}
- Context/Transcript: ${_transcript.text}
- โจทย์: ${_qText.text}
- ตัวเลือก: A:${_optA.text}, B:${_optB.text}, C:${_optC.text}, D:${_optD.text}
- เฉลยที่ถูกต้อง: $_selectedCorrectAnswer

ช่วยตอบกลับในรูปแบบ JSON เท่านั้น (ห้ามมี Markdown):
{
  "category": "เลือกจากหมวดหมู่ด้านบนเพียง 1 อย่าง ตาม Strict Priority Rules",
  "explanation": "1. แปล: (แปลโจทย์และตัวเลือก) 2. วิเคราะห์: (อธิบายเหตุผลสั้นๆ ตรงประเด็น) 3. ตัดตัวเลือก: (เหตุผลที่ข้ออื่นผิด) 4. ศัพท์น่ารู้: (3-5 คำ) ***ข้อกำหนดห้ามละเมิด: ห้ามอธิบายถึงกฎลำดับความสำคัญ ห้ามอ้างถึงหมายเลขพาร์ทอื่นๆ และห้ามให้เหตุผลเชิงเปรียบเทียบกฎ ให้วิเคราะห์เฉพาะเนื้อหาโจทย์ข้อนี้เท่านั้น***"
}
""";

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        // ทำความสะอาด JSON จาก AI
        final String rawJson = response.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final Map<String, dynamic> data = jsonDecode(rawJson);

        setState(() {
          _category.text = data['category'] ?? "";
          _explanation.text = data['explanation'] ?? "";
        });
      }
    } catch (e) {
      _showSnackBar("AI Error: $e");
    } finally {
      setState(() => _isGeneratingAI = false);
    }
  }

  // ฟังก์ชันเสริมสำหรับแจ้งเตือน
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'test_id': int.tryParse(_testId.text),
      'part': int.tryParse(_part.text),
      'category': _category.text.trim(), // <--- เพิ่มบรรทัดนี้
      'question_no': int.tryParse(_qNo.text),
      'question_text': _qText.text,
      'transcript': _transcript.text,
      'option_a': _optA.text,
      'option_b': _optB.text,
      'option_c': _optC.text,
      'option_d': _optD.text,
      'correct_answer': _selectedCorrectAnswer,
      'explanation': _explanation.text,
      'passage_group_id': _passageGroupId.text.isEmpty
          ? null
          : _passageGroupId.text,
      'audio_url': _audioUrl.text,
      'image_url': _imageUrl.text,
      'start_time': int.tryParse(_startTime.text) ?? 0,
      'end_time': int.tryParse(_endTime.text) ?? 0,
    };

    // ส่วนที่เหลือเหมือนเดิม (try-catch-finally)
    try {
      if (widget.editData != null) {
        await _supabase
            .from('practice_test')
            .update(data)
            .eq('id', widget.editData!['id']);
      } else {
        await _supabase.from('practice_test').insert(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar("Save Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editData == null ? "เพิ่มข้อสอบ" : "แก้ไขข้อสอบ"),
        backgroundColor: Colors.blueAccent.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("ข้อมูลพื้นฐาน"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _testId,
                            "Test ID",
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(_part, "Part", isNumber: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _qNo,
                            "ข้อที่",
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(_qText, "โจทย์", maxLines: 2),
                    _buildTextField(
                      _transcript,
                      "Passage / Transcript",
                      maxLines: 3,
                    ),

                    _buildSectionTitle("เฉลยและตัวเลือก"),
                    _buildTextField(_optA, "Option A"),
                    _buildTextField(_optB, "Option B"),
                    _buildTextField(_optC, "Option C"),
                    _buildTextField(_optD, "Option D"),
                    const Text(
                      "เฉลยที่ถูกต้อง:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'A', label: Text('A')),
                          ButtonSegment(value: 'B', label: Text('B')),
                          ButtonSegment(value: 'C', label: Text('C')),
                          ButtonSegment(value: 'D', label: Text('D')),
                        ],
                        selected: {_selectedCorrectAnswer},
                        onSelectionChanged: (val) =>
                            setState(() => _selectedCorrectAnswer = val.first),
                      ),
                    ),

                    _buildSectionTitle("คำอธิบายเฉลย (AI)"),
                    Stack(
                      children: [
                        _buildTextField(
                          _explanation,
                          "คำอธิบาย...",
                          maxLines: 8,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: ElevatedButton.icon(
                            onPressed: _isGeneratingAI
                                ? null
                                : _generateExplanationWithAI,
                            icon: _isGeneratingAI
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(
                              _isGeneratingAI ? "กำลังคิด..." : "AI สรุปสั้นๆ",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade50,
                              foregroundColor: Colors.purple.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      _category,
                      "หมวดหมู่ (เช่น Tense, Vocab) - AI จะระบุให้อัตโนมัติ สามารถแก้ไขได้",
                    ),

                    const SizedBox(height: 8),

                    _buildSectionTitle("สื่อและเวลา (ถ้ามี)"),
                    _buildTextField(_audioUrl, "Audio URL"),
                    _buildTextField(
                      _imageUrl,
                      "Image URL",
                    ), // เพิ่มช่องกรอก Image URL ใน UI เรียบร้อยครับ
                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingAI ? null : _aiScanAndFill,
                        icon: _isGeneratingAI
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                color: Colors.purple,
                              ),
                        label: Text(
                          _isGeneratingAI
                              ? "กำลังประมวลผล..."
                              : "AI Scan & Fill (ดึงข้อความจากรูป)",
                          style: TextStyle(color: Colors.purple.shade900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade50,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.purple.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _startTime,
                            "เริ่ม (วิ)",
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            _endTime,
                            "จบ (วิ)",
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "บันทึกข้อมูลทั้งหมด",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
