import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? ListView(
                      children: [
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
                        final createdAt =
                            DateTime.tryParse('${item['created_at']}');

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
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
