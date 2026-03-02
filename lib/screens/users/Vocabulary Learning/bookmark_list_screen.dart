import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vocab_detail_screen.dart';

// ─── Palette (เหมือน dashboard) ───────────────────────────────────────────────
class _P {
  static const bg         = Color(0xFFF8F9FC);
  static const surface    = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2F4F8);
  static const border     = Color(0xFFEAECF2);
  static const blue       = Color(0xFF1A56DB);
  static const blueLight  = Color(0xFFEEF3FF);
  static const red        = Color(0xFFDC2626);
  static const redBg      = Color(0xFFFEF2F2);
  static const teal       = Color(0xFF0891B2);
  static const tealBg     = Color(0xFFECFEFF);
  static const textPri    = Color(0xFF0F1729);
  static const textSec    = Color(0xFF64748B);
  static const textMute   = Color(0xFFADB5C7);
}

class BookmarkListScreen extends StatefulWidget {
  const BookmarkListScreen({super.key});

  @override
  State<BookmarkListScreen> createState() => _BookmarkListScreenState();
}

class _BookmarkListScreenState extends State<BookmarkListScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>>? _bookmarks;
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();

    // Realtime listener
    _supabase
        .channel('public:bookmarks')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookmarks',
          callback: (_) => _fetchBookmarks(),
        )
        .subscribe();
  }

  Future<void> _fetchBookmarks() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('bookmarks')
          .select('*, vocabularies(*)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _bookmarks = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bookmarks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeBookmark(String bookmarkId, String word) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _P.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบ Bookmark?',
            style: TextStyle(
                color: _P.textPri,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        content: Text('ลบ "$word" ออกจาก Bookmark?',
            style: const TextStyle(color: _P.textSec, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก',
                style: TextStyle(color: _P.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ',
                style: TextStyle(
                    color: _P.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('bookmarks').delete().eq('id', bookmarkId);
    } catch (e) {
      debugPrint('Error removing bookmark: $e');
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_bookmarks == null) return [];
    if (_search.isEmpty) return _bookmarks!;
    final q = _search.toLowerCase();
    return _bookmarks!.where((item) {
      final v = item['vocabularies'];
      if (v == null) return false;
      return (v['headword'] ?? '').toLowerCase().contains(q) ||
          (v['Translation_TH'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _P.bg,
      body: Column(children: [
        // ── Header ─────────────────────────────────────────────────────
        Container(
          color: _P.bg,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              // Top row
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                child: Row(children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: _P.textPri),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Bookmarks',
                        style: TextStyle(
                            color: _P.textPri,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                  ),
                  if (_bookmarks != null && _bookmarks!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _P.blueLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_bookmarks!.length} คำ',
                          style: const TextStyle(
                              color: _P.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),

              // Search bar
              if (!_isLoading &&
                  _bookmarks != null &&
                  _bookmarks!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _P.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _P.border),
                    ),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _search = v.trim()),
                      style: const TextStyle(
                          color: _P.textPri, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'ค้นหาคำศัพท์...',
                        hintStyle: TextStyle(
                            color: _P.textMute, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: _P.textMute, size: 18),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),

              // Divider
              const Divider(height: 1, color: _P.border),
            ]),
          ),
        ),

        // ── Body ───────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: _P.blue, strokeWidth: 2))
              : _bookmarks == null || _bookmarks!.isEmpty
                  ? _emptyState()
                  : _filtered.isEmpty
                      ? _noResult()
                      : RefreshIndicator(
                          onRefresh: _fetchBookmarks,
                          color: _P.blue,
                          backgroundColor: _P.surface,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                20, 16, 20, 32),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _bookmarkCard(_filtered[i]),
                          ),
                        ),
        ),
      ]),
    );
  }

  // ── Bookmark Card ─────────────────────────────────────────────────────────
  Widget _bookmarkCard(Map<String, dynamic> item) {
    final vocab = item['vocabularies'];
    if (vocab == null) return const SizedBox.shrink();

    final word   = vocab['headword']?.toString() ?? '';
    final transTH= vocab['Translation_TH']?.toString() ?? '';
    final cefr   = vocab['CEFR']?.toString() ?? '';
    final partOfSpeech = vocab['part_of_speech']?.toString() ?? '';

    return Dismissible(
      key: ValueKey(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _P.redBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: _P.red, size: 22),
      ),
      confirmDismiss: (_) async {
        await _removeBookmark(item['id'].toString(), word);
        return false; // Realtime จะ update list เอง
      },
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context,
          VocabDetailScreen.routeName,
          arguments: vocab,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _P.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _P.border),
          ),
          child: Row(children: [
            // CEFR badge
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _P.tealBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cefr,
                    style: const TextStyle(
                        color: _P.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 14),

            // Word info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(word,
                      style: const TextStyle(
                          color: _P.textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  if (partOfSpeech.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(partOfSpeech,
                        style: const TextStyle(
                            color: _P.textMute,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(transTH,
                    style: const TextStyle(
                        color: _P.textSec, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            )),

            // Delete button
            GestureDetector(
              onTap: () =>
                  _removeBookmark(item['id'].toString(), word),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _P.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bookmark_remove_rounded,
                    color: _P.red, size: 18),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Empty States ──────────────────────────────────────────────────────────
  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _P.blueLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.bookmark_outline_rounded,
              color: _P.blue, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('ยังไม่มี Bookmark',
            style: TextStyle(
                color: _P.textPri,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('กดไอคอน Bookmark ในหน้าคำศัพท์\nเพื่อบันทึกคำที่สนใจ',
            textAlign: TextAlign.center,
            style: TextStyle(color: _P.textSec, fontSize: 13)),
      ]),
    );
  }

  Widget _noResult() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off_rounded,
            color: _P.textMute, size: 48),
        const SizedBox(height: 12),
        Text('ไม่พบ "$_search"',
            style: const TextStyle(
                color: _P.textSec, fontSize: 14)),
      ]),
    );
  }
}
