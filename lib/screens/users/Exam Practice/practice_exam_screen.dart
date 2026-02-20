import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'exam_result_screen.dart';

class PracticeExamScreen extends StatefulWidget {
  final int testId;
  const PracticeExamScreen({super.key, required this.testId});

  @override
  State<PracticeExamScreen> createState() => _PracticeExamScreenState();
}

class _PracticeExamScreenState extends State<PracticeExamScreen> {
  final _supabase = Supabase.instance.client;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final PageController _passagePageController = PageController();
  int _currentPassagePage = 0;

  // Data storage
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _allPassageImages = [];
  Map<int, Map<String, dynamic>> _partDirections = {};
  List<Map<String, dynamic>> _currentGroupQuestions = [];

  // State management
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};
  bool _isLoading = true;
  bool _isShowingDirection = true;
  bool _isNavigating = false; // ป้องกันกดรัว

  // Audio State
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? _currentGroupImageUrl;
  @override
  void initState() {
    super.initState();
    _initAudioListeners();
    _fetchAllData();
  }

  void _initAudioListeners() {
    _audioPlayer.onPositionChanged.listen((p) async {
      // เพิ่ม async
      if (!mounted ||
          _questions.isEmpty ||
          _currentIndex >= _questions.length ||
          _isNavigating)
        return;

      final currentQ = _questions[_currentIndex];
      final int partId = currentQ['part'] ?? 1;
      final directionData = _partDirections[partId];
      if (directionData == null) return;

      int endTime = 9999;
      if (_isShowingDirection) {
        endTime = (directionData['end_time'] as num?)?.toInt() ?? 9999;
      } else {
        endTime = (_currentGroupQuestions.isNotEmpty)
            ? (_currentGroupQuestions.last['end_time'] as num?)?.toInt() ?? 9999
            : (currentQ['end_time'] as num?)?.toInt() ?? 9999;
      }

      if (p.inSeconds >= endTime) {
        // --- จุดสำคัญ: ล็อคทันทีก่อนเรียกฟังก์ชันอื่น ---
        _isNavigating = true;

        try {
          await _audioPlayer.pause(); // หยุดเสียงและรอให้หยุดสนิทจริงๆ

          if (partId <= 4) {
            debugPrint("Audio reached endTime, auto-navigating...");
            // ไม่ต้องเรียก _handleNextStep() ซ้ำ เพราะเราล็อค _isNavigating ไปแล้ว
            // ให้ใช้ Logic การข้ามข้อตรงนี้เลย หรือแยกเป็นฟังก์ชันภายใน
            await _handleNextStep();
          } else {
            _isNavigating = false;
          }
        } catch (e) {
          debugPrint("Error in Audio Listener: $e");
          _isNavigating = false;
        }
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  // ฟังก์ชันใหม่สำหรับจัดการการ Next
  Future<void> _handleNextStep() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      // หยุดเสียงก่อนทำงานอื่น เพื่อป้องกัน OnPositionChanged ทำงานต่อ
      await _audioPlayer.stop();

      final currentQ = _questions[_currentIndex];
      int nextIndex = _currentIndex + _currentGroupQuestions.length;

      // --- กรณีจบข้อสอบ ---
      if (nextIndex >= _questions.length) {
        debugPrint("No more questions. Submitting...");
        // ปลดล็อค navigat ก่อนเข้าสู่กระบวนการ submit เพื่อไม่ให้ UI ค้างถ้าหน้า submit โหลดช้า
        setState(() => _isNavigating = false);
        await _submitExam();
        return;
      }

      // --- กรณีเปลี่ยนไปข้อถัดไป ---
      final nextQ = _questions[nextIndex];

      setState(() {
        _currentIndex = nextIndex;
        _updateCurrentGroup();
        _currentPassagePage = 0;

        if (nextQ['part'] != currentQ['part']) {
          _isShowingDirection = true;
        } else {
          // ถ้าอยู่ Part เดิมแต่เปลี่ยนกลุ่มข้อสอบ (เช่น Part 3 ไปชุดถัดไป)
          // หน้า Direction จะเป็น false อยู่แล้ว แต่ต้องโหลดเสียงใหม่
          _isShowingDirection = false;
        }
      });

      if (nextQ['part'] <= 4) {
        // โหลดเสียงสำหรับพาร์ทฟัง (ฟังก์ชัน _loadAudio จะปลด lock _isNavigating ให้เอง)
        await _loadAudio(isDirection: _isShowingDirection);
      } else {
        // สำหรับพาร์ท Reading (5-7) ไม่มีเสียง ให้ปลด lock ทันที
        setState(() {
          _isShowingDirection =
              false; // เผื่อกรณีเปลี่ยนจาก 4 ไป 5 แล้วไม่ได้ใช้ direction
          _isNavigating = false;
        });
      }

      if (_passagePageController.hasClients) {
        _passagePageController.jumpToPage(0);
      }
    } catch (e) {
      debugPrint("Navigation Error: $e");
      setState(() => _isNavigating = false);
    } finally {
      // ป้องกันปุ่มค้างถาวร
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isNavigating = false);
      });
    }
    print(
      "Current Index: $_currentIndex, Total Questions: ${_questions.length}",
    );
  }

  Future<void> _fetchAllData() async {
    try {
      final responses = await Future.wait([
        _supabase.from('part_directions').select(),
        _supabase
            .from('practice_test')
            .select()
            .eq('test_id', widget.testId)
            .order('question_no', ascending: true),
        _supabase.from('passages').select().order('sequence', ascending: true),
      ]);

      setState(() {
        _partDirections = {
          for (var v in responses[0]) int.parse(v['part_id'].toString()): v,
        };
        _questions = List<Map<String, dynamic>>.from(responses[1]);
        _allPassageImages = List<Map<String, dynamic>>.from(responses[2]);
        _isLoading = false;
        _currentIndex = 0;
        // เพิ่มบรรทัดนี้เพื่อให้กลุ่มเริ่มต้นถูกสร้างขึ้นทันทีที่โหลดเสร็จ
        _updateCurrentGroup();
      });

      if (_questions.isNotEmpty) {
        // บังคับให้ระบบรู้ว่ากำลังจะเตรียมโหลดเสียง
        setState(() => _isNavigating = true);
        _loadAudio(isDirection: true);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      }
    }
  }

  Future<void> _loadAudio({required bool isDirection}) async {
    // 1. ตรวจสอบเงื่อนไขพื้นฐาน
    if (_questions.isEmpty || !mounted || _currentIndex >= _questions.length) {
      if (mounted) setState(() => _isNavigating = false);
      return;
    }

    final currentQ = _questions[_currentIndex];
    final int partId = currentQ['part'] ?? 1;

    // 2. ถ้าเป็น Reading (Part 5+) ให้หยุดเสียงและปลดล็อคทันที
    if (partId >= 5) {
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      if (mounted) setState(() => _isNavigating = false);
      return;
    }

    // 3. เตรียมข้อมูล Audio
    final directionData = _partDirections[partId];
    String? audioUrl;
    int startTime = 0;

    if (isDirection) {
      audioUrl = directionData?['audio_url'];
      startTime = (directionData?['start_time'] as num?)?.toInt() ?? 0;
    } else {
      audioUrl = (currentQ['audio_url']?.toString().isNotEmpty == true)
          ? currentQ['audio_url']
          : directionData?['audio_url'];
      startTime = (currentQ['start_time'] as num?)?.toInt() ?? 0;
    }

    // 4. จัดการเรื่องเสียง
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        // [สำคัญ] หยุดเสียงเดิมให้สนิทก่อนเริ่มกระบวนการใหม่
        await _audioPlayer.stop();

        // ให้เวลาระบบจัดการ Memory เล็กน้อย (ช่วยลด AbortError บน Web/Android)
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;

        // ตั้งค่า Source และตำแหน่งเริ่มต้น
        await _audioPlayer.setSource(UrlSource(audioUrl));
        await _audioPlayer.seek(Duration(seconds: startTime));
        // เพิ่มส่วนนี้: ถ้าเป็นหน้า Direction ให้สั่ง resume ทันที
        // ถ้าเป็น Direction ให้ข้ามเช็ค _isNavigating หรือบังคับเล่นเลย
        if (mounted && (isDirection || _isNavigating)) {
          await _audioPlayer.resume();
        }
      } catch (e) {
        // จับ Error play() request was interrupted เพื่อไม่ให้แอปค้าง
        debugPrint("Audio Playback Loop Protected: $e");
      } finally {
        // ปลดล็อคปุ่มหลังจากโหลดเสร็จ (หน่วงเวลาเล็กน้อยเพื่อให้ UI พร้อม)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _isNavigating = false);
        });
      }
    } else {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  void _updateCurrentGroup() {
    if (_questions.isEmpty) return;

    final currentQ = _questions[_currentIndex];
    final groupId = currentQ['passage_group_id'];

    setState(() {
      if (groupId != null && groupId.toString().isNotEmpty) {
        // 1. ดึงคำถามทั้งหมดในกลุ่ม
        _currentGroupQuestions = _questions
            .where((q) => q['passage_group_id'] == groupId)
            .toList();

        // 2. ค้นหารูปภาพจากทุกข้อในกลุ่ม (หาข้อแรกที่มี image_url ไม่เป็นค่าว่าง)
        final firstWithImage = _currentGroupQuestions.firstWhere(
          (q) => q['image_url'] != null && q['image_url'].toString().isNotEmpty,
          orElse: () => {},
        );
        _currentGroupImageUrl = firstWithImage['image_url'];
      } else {
        _currentGroupQuestions = [currentQ];
        _currentGroupImageUrl = currentQ['image_url'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_questions.isEmpty)
      return const Scaffold(body: Center(child: Text("No questions found.")));

    final currentQ = _questions[_currentIndex];
    final int partId = currentQ['part'] ?? 1;

    // --- เพิ่ม Logic ตรงนี้ ---
    String questionTitle = "";
    if (_currentGroupQuestions.length > 1) {
      // ถ้ามีหลายข้อในกลุ่ม ให้ดึง Question No ของข้อแรกและข้อสุดท้ายในกลุ่มมาโชว์
      final firstNo = _currentGroupQuestions.first['question_no'];
      final lastNo = _currentGroupQuestions.last['question_no'];
      questionTitle = "Questions $firstNo-$lastNo";
    } else {
      // ถ้ามีข้อเดียว โชว์แบบเดิม
      questionTitle = "Question ${currentQ['question_no']}";
    }
    // -----------------------

    return PopScope(
      child: _isShowingDirection
          ? _buildDirectionScreen(partId)
          : Scaffold(
              backgroundColor: Colors.grey[50],
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo,
                title: Text(
                  "Part $partId - $questionTitle", // ใช้ตัวแปร questionTitle ที่สร้างไว้
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.grid_view_rounded),
                    onPressed: _showQuestionStatusSheet,
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (partId <= 4) _buildAudioControlBar(),
                  LinearProgressIndicator(
                    value: (_currentIndex + 1) / _questions.length,
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.indigo,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // แก้ Error No element ตรงนี้ครับ
                          if (_currentGroupQuestions.isNotEmpty)
                            _buildPassageContent(_currentGroupQuestions.first),

                          const SizedBox(height: 24),

                          if (_currentGroupQuestions.isEmpty)
                            const Center(child: Text("Loading questions...")),

                          ..._currentGroupQuestions.map((q) {
                            int actualIndex = _questions.indexOf(q);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "No. ${actualIndex + 1}",
                                  style: TextStyle(
                                    color: Colors.indigo.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // แสดงโจทย์ (ยกเว้น Part 6 ที่เป็น Passage)
                                if (q['part'] != 6)
                                  Text(
                                    q['question_text'] ?? "",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                // ใช้ _buildGroupOption ที่คุณสร้างไว้
                                _buildGroupOption(
                                  actualIndex,
                                  "A",
                                  q['option_a'],
                                ),
                                _buildGroupOption(
                                  actualIndex,
                                  "B",
                                  q['option_b'],
                                ),
                                _buildGroupOption(
                                  actualIndex,
                                  "C",
                                  q['option_c'],
                                ),
                                _buildGroupOption(
                                  actualIndex,
                                  "D",
                                  q['option_d'],
                                ),
                                const Divider(height: 40),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  _buildNavigationButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildGroupOption(int qIndex, String key, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    // เช็คว่าข้อนี้ (qIndex) เลือกข้อนี้ (key) อยู่หรือไม่
    bool isSelected = _userAnswers[qIndex] == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _userAnswers[qIndex] = key;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isSelected
                    ? Colors.indigo
                    : Colors.grey.shade200,
                child: Text(
                  key,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioControlBar() {
    final currentQ = _questions[_currentIndex];
    final int partId = currentQ['part'] ?? 1;

    // ถ้าเป็น Part 5-7 ไม่ต้องแสดงแถบควบคุมเสียง
    if (partId >= 5) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // แสดง Icon ลำโพงตามสถานะการเล่น
          Icon(
            _playerState == PlayerState.playing
                ? Icons.volume_up_rounded
                : Icons.volume_mute_rounded,
            color: _playerState == PlayerState.playing
                ? Colors.indigo
                : Colors.grey,
            size: 30,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _playerState == PlayerState.playing
                      ? "Listening Audio Playing..."
                      : "Audio Standby",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _playerState == PlayerState.playing
                        ? Colors.indigo
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                // แสดงความคืบหน้าแบบเรียบง่าย (Progress Bar) แทนการกด Seek
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    // คำนวณเปอร์เซ็นต์เวลาที่ผ่านไป เทียบกับ end_time ของกลุ่ม
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds / _duration.inSeconds
                        : 0.0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.indigo,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          // แสดงเวลาที่เหลือ
          Text(
            "${_position.inSeconds}s",
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassageContent(Map<String, dynamic> q) {
    final int partId = q['part'] ?? 1;

    // 1. กรณี Part 6 แสดง Transcript (ข้อสอบเติมคำในเนื้อเรื่อง)
    if (partId == 6) {
      final transcript = q['transcript']?.toString() ?? "";
      if (transcript.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.withOpacity(0.1)),
        ),
        child: Text(
          transcript,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
      );
    }

    // 2. สำหรับ Part 5 ปกติจะไม่มี Passage หรือรูปภาพ ให้ข้ามไปเลยเพื่อประหยัดทรัพยากร
    if (partId == 5) return const SizedBox.shrink();

    final String? groupId = q['passage_group_id']?.toString();

    // 3. กรณี Part 7 ที่มีหลาย Passages (ดึงจากตาราง passages)
    if (groupId != null && groupId.isNotEmpty) {
      final List<Map<String, dynamic>> groupImages = _allPassageImages
          .where((img) => img['passage_group_id']?.toString() == groupId)
          .toList();

      if (groupImages.isNotEmpty) {
        return Column(
          children: [
            Container(
              height: 450,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _passagePageController,
                    itemCount: groupImages.length,
                    onPageChanged: (index) {
                      if (mounted) setState(() => _currentPassagePage = index);
                    },
                    itemBuilder: (context, index) {
                      final imageUrl =
                          groupImages[index]['image_url']?.toString() ?? "";
                      if (imageUrl.isEmpty)
                        return const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        );

                      return InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            // เพิ่ม Error Builder เพื่อไม่ให้แอปค้างถ้ารูปเสีย
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                ),
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_currentPassagePage > 0)
                    _buildScrollButton(Icons.arrow_back_ios, () {
                      _passagePageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }, isLeft: true),
                  if (_currentPassagePage < groupImages.length - 1)
                    _buildScrollButton(Icons.arrow_forward_ios, () {
                      _passagePageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }, isLeft: false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Passage ${_currentPassagePage + 1} of ${groupImages.length}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      }
    }

    // 4. กรณีมีรูปภาพรูปเดียว (ใช้ _currentGroupImageUrl ที่คำนวณไว้แล้วจาก _updateCurrentGroup)
    if (_currentGroupImageUrl != null && _currentGroupImageUrl!.isNotEmpty) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxHeight: 400,
        ), // จำกัดความสูงเพื่อไม่ให้ Overflow
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.network(
              _currentGroupImageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(20),
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Helper Widget สำหรับปุ่มลูกศร
  Widget _buildScrollButton(
    IconData icon,
    VoidCallback onPressed, {
    required bool isLeft,
  }) {
    return Positioned(
      left: isLeft ? 5 : null,
      right: isLeft ? null : 5,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.indigo),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final currentQ = _questions[_currentIndex];
    final int partId = currentQ['part'] ?? 1;
    // อนุญาตให้กดย้อนกลับได้เฉพาะพาร์ท Reading (5-7) เท่านั้น
    final bool canGoBack = partId >= 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (canGoBack)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // ตรวจสอบว่าข้อก่อนหน้ายังเป็นพาร์ท Reading อยู่หรือไม่
                  if (_currentIndex > 0) {
                    int prevIndex = _currentIndex - 1;
                    // ถ้าถอยไปแล้วจะเจอ Part 4 ให้บล็อกไว้
                    if (_questions[prevIndex]['part'] <= 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "ไม่สามารถย้อนกลับไปพาร์ท Listening ได้",
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _currentIndex = prevIndex;
                      // วนลูปถอยหลังไปจนถึงต้นกลุ่ม (Passage เดียวกัน)
                      while (_currentIndex > 0 &&
                          _questions[_currentIndex]['passage_group_id'] ==
                              _questions[_currentIndex -
                                  1]['passage_group_id']) {
                        _currentIndex--;
                      }
                      _updateCurrentGroup();
                    });
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text("Back"),
              ),
            ),

          if (canGoBack) const SizedBox(width: 15),

          Expanded(
            child: ElevatedButton(
              onPressed: _isNavigating ? null : () => _handleNextStep(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                (_currentIndex + _currentGroupQuestions.length >=
                        _questions.length)
                    ? "Submit"
                    : "Next",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionScreen(int partId) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "PART $partId",
              style: const TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.w900,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 20),
            if (_partDirections[partId]?['image_url'] != null)
              Expanded(
                child: Image.network(_partDirections[partId]!['image_url']),
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  setState(() => _isShowingDirection = false);
                  await _loadAudio(isDirection: false);
                  if (partId <= 4) await _audioPlayer.resume();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "START QUESTIONS",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuestionStatusSheet() {
    final currentQ = _questions[_currentIndex];
    final int currentPart = currentQ['part'] ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // เพื่อให้แสดงผลได้เต็มที่
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text(
              "Question Map",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusLegend(Colors.indigo, "Current"),
                const SizedBox(width: 15),
                _buildStatusLegend(Colors.green, "Answered"),
                const SizedBox(width: 15),
                _buildStatusLegend(Colors.grey.shade300, "Locked/Not Done"),
              ],
            ),
            const Divider(height: 30),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final targetQ = _questions[index];
                  final int targetPart = targetQ['part'] ?? 1;
                  final bool isAnswered = _userAnswers.containsKey(index);
                  final bool isCurrent = index == _currentIndex;

                  // --- Logic การล็อค ---
                  bool isLocked = false;
                  // 1. ถ้าเป็น Listening (1-4) ห้ามกดเลือกข้อ (ยกเว้นข้อปัจจุบัน)
                  if (currentPart <= 4 && !isCurrent) {
                    isLocked = true;
                  }
                  // 2. ถ้ามาถึง Reading (5-7) แล้ว ห้ามย้อนไป Listening (1-4)
                  if (currentPart >= 5 && targetPart <= 4) {
                    isLocked = true;
                  }

                  return GestureDetector(
                    onTap: isLocked
                        ? null
                        : () {
                            setState(() {
                              _currentIndex = index;
                              _isShowingDirection = false;
                              _updateCurrentGroup();
                            });
                            _loadAudio(isDirection: false);
                            Navigator.pop(context);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.indigo
                            : (isAnswered
                                  ? Colors.green.shade100
                                  : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLocked
                              ? Colors.transparent
                              : Colors.indigo.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "${targetQ['question_no']}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isLocked
                                ? Colors.grey.shade400
                                : (isCurrent ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _submitExam() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
      _isLoading = true;
    });

    int lRaw = 0;
    int rRaw = 0;

    try {
      // 1. เตรียมข้อมูลสำหรับสรุปทักษะ (Skill Summary) ในเครื่องก่อน
      // Map นี้จะเก็บว่าแต่ละ Category ตอบถูกกี่ข้อ ตอบผิดกี่ข้อ
      Map<String, Map<String, int>> skillSummary = {};

      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final userAnswer = _userAnswers[i];
        final bool isCorrect =
            userAnswer != null && userAnswer == q['correct_answer'];
        final String category = q['category'] ?? 'General';

        // นับคะแนน Listening/Reading
        if (isCorrect) {
          int part = q['part'] ?? 1;
          if (part <= 4)
            lRaw++;
          else
            rRaw++;
        }

        // เก็บสรุปผลลงใน Map (ยังไม่ยิง API)
        if (!skillSummary.containsKey(category)) {
          skillSummary[category] = {'correct': 0, 'total': 0};
        }
        skillSummary[category]!['total'] =
            skillSummary[category]!['total']! + 1;
        if (isCorrect) {
          skillSummary[category]!['correct'] =
              skillSummary[category]!['correct']! + 1;
        }
      }

      // 2. ยิง API บันทึกผลสอบหลัก (ยิงครั้งเดียว)
      await _supabase.from('exam_submissions').insert({
        'user_id': _supabase.auth.currentUser?.id,
        'test_id': widget.testId,
        'listening_raw': lRaw,
        'reading_raw': rRaw,
        'score': lRaw + rRaw,
        'total_questions': _questions.length,
        'answers': _userAnswers.map(
          (k, v) => MapEntry(k.toString(), v),
        ), // เก็บคำตอบ JSONB
        'questions_snapshot':
            _questions, // บันทึกโจทย์+เฉลย+คำอธิบาย ณ ตอนนี้ลง JSONB
      });

      // 3. ส่งข้อมูลสรุปทักษะ (แก้ปัญหาค้าง)
      // ใช้ Future.wait เพื่อให้มันทำงานพร้อมกัน หรือส่งแบบก้อนเดียวถ้าทำ RPC ใหม่ได้
      // แต่เบื้องต้น การวนลูปยิง API แค่ตามจำนวน "Category" (ซึ่งมักจะมีไม่กี่อัน) จะเร็วกว่ายิง 100 ข้อมาก
      List<Future> skillUpdates = [];
      skillSummary.forEach((cat, stats) {
        skillUpdates.add(
          _supabase
              .rpc(
                'update_user_skill_v2',
                params: {
                  // แนะนำให้สร้าง RPC ตัวใหม่ที่รับผลรวม
                  'u_id': _supabase.auth.currentUser?.id,
                  'cat': cat,
                  'correct_count': stats['correct'],
                  'total_count': stats['total'],
                },
              )
              .catchError((e) => debugPrint("Skill Update Error: $e")),
        );
      });

      // ถ้ายอมให้บันทึกสกิลช้าหน่อยแต่แอปไปต่อได้ ให้เอา await ออก หรือรอแค่แป๊บเดียว
      await Future.wait(skillUpdates).timeout(const Duration(seconds: 5));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExamResultScreen(
              questions: _questions,
              userAnswers: _userAnswers,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Submit Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาดในการส่ง: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }
}
