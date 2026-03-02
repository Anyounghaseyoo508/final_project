import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../controller/part_practice_controller.dart';
import 'part_practice_result_screen.dart';

class PartPracticeExamScreen extends StatefulWidget {
  final int part;
  final String title;

  const PartPracticeExamScreen({
    super.key,
    required this.part,
    required this.title,
  });

  @override
  State<PartPracticeExamScreen> createState() => _PartPracticeExamScreenState();
}

class _PartPracticeExamScreenState extends State<PartPracticeExamScreen> {
  late final PartPracticeController _ctrl;

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;

  // ตัวแปรของข้อปัจจุบัน
  String _currentAudioUrl = '';
  int _startSec = 0;   // วินาทีเริ่มในไฟล์ MP3
  int _endSec = 0;     // วินาทีสิ้นสุดในไฟล์ MP3

  // position จริงของ player (absolute ตาม MP3)
  int _absolutePosSec = 0;

  // Slider value = relative position ภายในช่วงของข้อ (0.0 – 1.0)
  double _sliderValue = 0.0;
  bool _userDragging = false; // กำลังลาก slider อยู่หรือเปล่า

  bool _audioReady = false;  // โหลด source สำเร็จแล้ว
  bool _hasAudio = false;    // ข้อนี้มี audio_url หรือเปล่า

  bool get _isListeningPart => widget.part <= 4;

  // ช่วงเวลา "ของข้อนี้" เป็น Duration
  Duration get _clipStart => Duration(seconds: _startSec);
 
  @override
  void initState() {
    super.initState();
    _ctrl = PartPracticeController(
      selectedPart: widget.part,
      selectedTitle: widget.title,
    );
    _ctrl.addListener(_onControllerUpdate);

    if (_isListeningPart) _setupAudioListeners();
  }

  // ── Controller listener ────────────────────────────────────────────────────

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
    // โหลดเสียงใหม่ทุกครั้งที่ controller notify (รวมถึงตอนโหลดข้อมูลเสร็จ)
    if (!_ctrl.isLoading && _isListeningPart) {
      _prepareAudio();
    }
  }

  // ── Audio: setup listeners ─────────────────────────────────────────────────

  void _setupAudioListeners() {
    // track position แบบ absolute
    _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final absSec = pos.inSeconds;

      // ถ้าเกิน end_time → หยุดและ reset slider ไปที่ต้น
      if (_endSec > 0 && absSec >= _endSec) {
        _audioPlayer.pause();
        _audioPlayer.seek(_clipStart);
        setState(() {
          _absolutePosSec = _startSec;
          _sliderValue = 0.0;
          _playerState = PlayerState.paused;
        });
        return;
      }

      if (!_userDragging) {
        final len = _endSec - _startSec;
        setState(() {
          _absolutePosSec = absSec;
          _sliderValue = len > 0
              ? (absSec - _startSec).clamp(0, len) / len
              : 0.0;
        });
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
  }

  // ── Audio: เตรียมเสียงสำหรับข้อปัจจุบัน ───────────────────────────────────

  Future<void> _prepareAudio() async {
    final q = _ctrl.currentQuestion;
    if (q == null) return;

    final audioUrl = q['audio_url']?.toString() ?? '';
    final startSec = (q['start_time'] as num?)?.toInt() ?? 0;
    final endSec   = (q['end_time']   as num?)?.toInt() ?? 0;
    final hasAudio = audioUrl.isNotEmpty && endSec > startSec;

    // ถ้า URL ข้อใหม่ต่างจากเดิม → ต้อง setSource ใหม่
    // ถ้า URL เดิมแต่ช่วงต่างกัน → แค่ seek ไปที่ startSec ใหม่
    final needNewSource = audioUrl != _currentAudioUrl;

    // หยุดก่อนเสมอ
    await _audioPlayer.pause();

    setState(() {
      _hasAudio = hasAudio;
      _startSec = startSec;
      _endSec   = endSec;
      _absolutePosSec = startSec;
      _sliderValue = 0.0;
      _audioReady = false;
      _playerState = PlayerState.paused;
    });

    if (!hasAudio) return;

    try {
      if (needNewSource) {
        _currentAudioUrl = audioUrl;
        await _audioPlayer.setSource(UrlSource(audioUrl));
      }
      // seek ไปที่จุดเริ่มของข้อนี้
      await _audioPlayer.seek(_clipStart);
      setState(() => _audioReady = true);
    } catch (e) {
      debugPrint('Audio prepare error: $e');
      setState(() => _audioReady = false);
    }
  }

  // ── Audio: play / pause ────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (!_audioReady) return;
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      // ถ้า slider อยู่ที่ 0 หรือ position ล้ำ end → seek กลับต้นก่อน
      if (_absolutePosSec >= _endSec) {
        await _audioPlayer.seek(_clipStart);
        setState(() {
          _absolutePosSec = _startSec;
          _sliderValue = 0.0;
        });
      }
      await _audioPlayer.resume();
    }
  }

  // ── Audio: slider seek ─────────────────────────────────────────────────────

  void _onSliderChanged(double value) {
    setState(() {
      _userDragging = true;
      _sliderValue = value;
    });
  }

  Future<void> _onSliderChangeEnd(double value) async {
    final len = _endSec - _startSec;
    final targetSec = _startSec + (value * len).round();
    final targetDur = Duration(seconds: targetSec.clamp(_startSec, _endSec));
    await _audioPlayer.seek(targetDur);
    setState(() {
      _userDragging = false;
      _absolutePosSec = targetSec;
      _sliderValue = value;
    });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goNext() {
    _audioPlayer.pause();
    _ctrl.goNext();
    // _prepareAudio จะถูกเรียกจาก _onControllerUpdate
  }

  void _goBack() {
    _audioPlayer.pause();
    _ctrl.goBack();
  }

  void _goToIndex(int index) {
    _audioPlayer.pause();
    _ctrl.goToIndex(index);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerUpdate);
    _ctrl.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_ctrl.error != null) {
      return Scaffold(body: Center(child: Text('Error: ${_ctrl.error}')));
    }
    if (_ctrl.questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('ไม่พบข้อสอบในชุดนี้')));
    }

    final q = _ctrl.currentQuestion!;
    final partId = widget.part;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await _showExitDialog();
        if (confirmed == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.indigo,
          elevation: 0,
          title: Text(
            'Part ${widget.part} — ข้อ ${_ctrl.currentIndex + 1}/${_ctrl.questions.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _showQuestionMap,
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_ctrl.currentIndex + 1) / _ctrl.questions.length,
              backgroundColor: Colors.indigo.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
              minHeight: 4,
            ),

            // Audio player (Part 1–4 เท่านั้น)
            if (_isListeningPart) _buildAudioBar(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges
                    Row(
                      children: [
                        _badge('ข้อ ${q['question_no']}',
                            Colors.indigo.shade50, Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _badge(q['category'] ?? '',
                              Colors.grey.shade100, Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Image
                    if (_hasImage(q)) _buildImage(q),

                    // Transcript / Passage (Part 3,4,6,7)
                    if (_hasPassage(q, partId)) _buildPassage(q, partId),

                    // Question text
                    if (partId != 6 &&
                        (q['question_text'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        q['question_text'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Options
                    ...['A', 'B', 'C', 'D'].map((key) {
                      final value = q['option_${key.toLowerCase()}'];
                      if (value == null || value.toString().isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return _buildOption(key, value.toString(), partId);
                    }),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ─── Audio Bar ─────────────────────────────────────────────────────────────

  Widget _buildAudioBar() {
    final isPlaying = _playerState == PlayerState.playing;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: !_hasAudio
          ? Row(
              children: [
                Icon(Icons.volume_off, color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 10),
                Text('ไม่มีไฟล์เสียงสำหรับข้อนี้',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            )
          : Row(
              children: [
                // Play / Pause button
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _audioReady ? Colors.indigo : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Slider (เลื่อนได้)
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                      activeTrackColor: Colors.indigo,
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: Colors.indigo,
                      overlayColor: Colors.indigo.withOpacity(0.15),
                    ),
                    child: Slider(
                      value: _sliderValue.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: _audioReady ? _onSliderChanged : null,
                      onChangeEnd: _audioReady ? _onSliderChangeEnd : null,
                    ),
                  ),
                ),

                // ปุ่มฟังใหม่ (replay)
                GestureDetector(
                  onTap: _audioReady
                      ? () async {
                          await _audioPlayer.seek(_clipStart);
                          setState(() {
                            _absolutePosSec = _startSec;
                            _sliderValue = 0.0;
                          });
                          await _audioPlayer.resume();
                        }
                      : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.replay_rounded,
                      color: _audioReady
                          ? Colors.indigo.shade700
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  bool _hasImage(Map<String, dynamic> q) =>
      (q['image_url']?.toString() ?? '').isNotEmpty;

  bool _hasPassage(Map<String, dynamic> q, int partId) {
    final t = q['transcript']?.toString() ?? '';
    return t.isNotEmpty &&
        (partId == 3 || partId == 4 || partId == 6 || partId == 7);
  }

  Widget _buildImage(Map<String, dynamic> q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(maxHeight: 300),
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
            q['image_url'],
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(20),
              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildPassage(Map<String, dynamic> q, int partId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article_outlined,
                  color: Colors.indigo.shade400, size: 16),
              const SizedBox(width: 6),
              Text(
                partId <= 4 ? 'Transcript' : 'Passage',
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(q['transcript'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildOption(String key, String value, int partId) {
    final selected = _ctrl.userAnswers[_ctrl.currentIndex];
    final isSelected = selected == key;
    final hideText = partId == 1 || partId == 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _ctrl.selectAnswer(key),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.indigo : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    key,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (!hideText) ...[
                const SizedBox(width: 12),
                Expanded(
                    child: Text(value,
                        style: const TextStyle(fontSize: 15))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final answered = _ctrl.userAnswers.length;
    final total = _ctrl.questions.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'ตอบแล้ว $answered / $total ข้อ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              if (_ctrl.currentIndex > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goBack,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.indigo.shade300),
                    ),
                    child: const Text('ก่อนหน้า'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      _ctrl.isLastQuestion ? _confirmSubmit : _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ctrl.isLastQuestion
                        ? Colors.green
                        : Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: _ctrl.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _ctrl.isLastQuestion ? '✓ ส่งคำตอบ' : 'ถัดไป',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ───────────────────────────────────────────────────────────────

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ออกจากการทำข้อสอบ?'),
        content: const Text('ความคืบหน้าจะไม่ถูกบันทึก'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ออก',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmSubmit() {
    final unanswered = _ctrl.questions.length - _ctrl.userAnswers.length;
    if (unanswered > 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ยังมีข้อที่ไม่ได้ตอบ'),
          content: Text(
              'เหลืออีก $unanswered ข้อที่ยังไม่ได้ตอบ\nต้องการส่งคำตอบเลยไหม?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('กลับไปทำต่อ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submit();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo),
              child: const Text('ส่งเลย',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    await _audioPlayer.stop();
    final result = await _ctrl.submitExam();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => PartPracticeResultScreen(result: result)),
    );
  }

  // ─── Question Map ──────────────────────────────────────────────────────────

  void _showQuestionMap() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('แผนที่ข้อสอบ',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legend(Colors.indigo, 'ข้อปัจจุบัน'),
                const SizedBox(width: 16),
                _legend(Colors.green.shade300, 'ตอบแล้ว'),
                const SizedBox(width: 16),
                _legend(Colors.grey.shade200, 'ยังไม่ตอบ'),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _ctrl.questions.length,
                itemBuilder: (_, i) {
                  final isCurrent = i == _ctrl.currentIndex;
                  final isAnswered = _ctrl.userAnswers.containsKey(i);
                  return GestureDetector(
                    onTap: () {
                      _goToIndex(i);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.indigo
                            : isAnswered
                                ? Colors.green.shade100
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent
                              ? Colors.indigo
                              : isAnswered
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${_ctrl.questions[i]['question_no']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? Colors.white
                                : Colors.black87,
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

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
