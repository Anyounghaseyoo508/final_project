import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Global notifier — ไฟล์เดียวกันก็ได้ หรือจะแยกไปไว้ lib/notifiers/unread_notifier.dart แล้ว import ก็ได้
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

      // อัปเดต badge ทุกครั้งที่โหลดข้อมูลใหม่
      unreadCountNotifier.value = list.where((n) => n['is_read'] != true).length;

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
                            title: Text(item['title'] ?? '-'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['body'] ?? ''),
                                if (createdAt != null)
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm')
                                        .format(createdAt.toLocal()),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                            onTap: () => _markAsRead(item['id'] as int),
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