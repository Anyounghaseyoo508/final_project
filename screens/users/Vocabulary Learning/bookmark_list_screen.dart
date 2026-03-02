import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vocab_detail_screen.dart';

class BookmarkListScreen extends StatefulWidget {
  const BookmarkListScreen({super.key});

  @override
  State<BookmarkListScreen> createState() => _BookmarkListScreenState();
}

class _BookmarkListScreenState extends State<BookmarkListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>>? _bookmarks;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
    // ฟังการเปลี่ยนแปลงในตาราง bookmarks แบบ Realtime
    _supabase
        .channel('public:bookmarks')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookmarks',
          callback: (payload) {
            _fetchBookmarks(); // เมื่อมีการเปลี่ยนแปลง (เพิ่ม/ลบ) ให้ดึงข้อมูลใหม่ทันที
          },
        )
        .subscribe();
  }

  // ดึงข้อมูลแบบ Join Table เพื่อให้ได้ข้อมูลคำศัพท์มาในก้อนเดียว
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
      debugPrint("Error fetching bookmarks: $e");
    }
  }

  Future<void> _removeBookmark(String bookmarkId) async {
    try {
      // ลบข้อมูลใน Database
      await _supabase.from('bookmarks').delete().eq('id', bookmarkId);
      // หมายเหตุ: _fetchBookmarks() จะถูกเรียกอัตโนมัติจาก listener ใน initState
    } catch (e) {
      debugPrint("Error removing bookmark: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookmarks == null || _bookmarks!.isEmpty) {
      return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("ไม่มีคำศัพท์ที่บันทึกไว้", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
    }

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarks!.length,
        itemBuilder: (context, index) {
          final item = _bookmarks![index];
          final vocab = item['vocabularies'];

          if (vocab == null) return const SizedBox.shrink();

          return Card(
            key: ValueKey(
              item['id'],
            ), // สำคัญ: ใช้ ID ของ bookmark ป้องกัน UI ค้าง
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                vocab['headword'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(vocab['Translation_TH'] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.bookmark_remove, color: Colors.red),
                onPressed: () => _removeBookmark(item['id'].toString()),
              ),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  VocabDetailScreen.routeName,
                  arguments: vocab,
                );
              },
            ),
          );
        },
      ),
    );
  }
}