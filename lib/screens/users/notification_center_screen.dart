import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final unreadCountNotifier = ValueNotifier<int>(0);

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('user_notifications')
          .select('id, title, body, is_read, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final list = List<Map<String, dynamic>>.from(response);
      unreadCountNotifier.value =
          list.where((n) => n['is_read'] != true).length;

      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดแจ้งเตือนไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _supabase
          .from('user_notifications')
          .update({'is_read': true}).eq('id', id);
      await _loadNotifications();
    } catch (_) {}
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await _supabase.from('user_notifications').delete().eq('id', id);
      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _deleteReadNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('user_notifications')
          .delete()
          .eq('user_id', user.id)
          .eq('is_read', true);
      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบที่อ่านแล้วไม่สำเร็จ: $e')),
      );
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    final isRead = item['is_read'] == true;
    final id = item['id'] as int;

    // mark as read ทันทีที่เปิด bottom sheet
    if (!isRead) _markAsRead(id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationDetailSheet(
        item: item,
        createdAt: DateTime.tryParse('${item['created_at']}'),
        onDelete: () async {
          Navigator.pop(context);
          await _deleteNotification(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        actions: [
          TextButton(
            onPressed: _deleteReadNotifications,
            child: const Text('ลบที่อ่านแล้ว'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('ยังไม่มีการแจ้งเตือน')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        final isRead = item['is_read'] == true;
                        final createdAt = DateTime.tryParse(
                          '${item['created_at']}',
                        );

                        return Card(
                          color: isRead ? null : Colors.blue.shade50,
                          child: ListTile(
                            leading: Icon(
                              isRead
                                  ? Icons.mark_email_read
                                  : Icons.notifications_active,
                              color: isRead ? Colors.grey : Colors.blue,
                            ),
                            title: Text(
                              item['title'] ?? '-',
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['body'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (createdAt != null)
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm')
                                        .format(createdAt.toLocal()),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                            onTap: () => _showDetail(item),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  _deleteNotification(item['id'] as int),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ── Bottom Sheet Detail ───────────────────────────────────────────────────────
class _NotificationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final DateTime? createdAt;
  final VoidCallback onDelete;

  const _NotificationDetailSheet({
    required this.item,
    required this.createdAt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = item['is_read'] == true;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle bar ──
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  // ── สถานะ badge ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.grey.shade100
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isRead
                                  ? Icons.mark_email_read
                                  : Icons.notifications_active,
                              size: 13,
                              color: isRead ? Colors.grey : Colors.blue,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isRead ? 'อ่านแล้ว' : 'ยังไม่ได้อ่าน',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isRead ? Colors.grey : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── หัวข้อ ──
                  Text(
                    item['title'] ?? '-',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F1729),
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── วันเวลา ──
                  if (createdAt != null)
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(createdAt!.toLocal()),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── ข้อความเต็ม ──
                  Text(
                    item['body'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF334155),
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── ปุ่มลบ ──
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                    label: const Text('ลบการแจ้งเตือนนี้',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}