import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminMonitoringScreen extends StatefulWidget {
  const AdminMonitoringScreen({super.key});

  @override
  State<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends State<AdminMonitoringScreen> {
  final _supabase = Supabase.instance.client;
  
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalSubmissions = 0;
  double _avgScore = 0;
  List<Map<String, dynamic>> _recentIssues = [];
  List<Map<String, dynamic>> _topUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Total users
      final usersCount = await _supabase
          .from('users')
          .select('id', const FetchOptions(count: CountOption.exact, head: true));

      // Active users (logged in last 7 days)
      final activeCount = await _supabase
          .from('users')
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .gte('last_sign_in_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String());

      // Total submissions
      final submissionsResponse = await _supabase
          .from('exam_submissions')
          .select('score');

      final submissions = List<Map<String, dynamic>>.from(submissionsResponse);
      final avgScore = submissions.isEmpty
          ? 0.0
          : submissions.map((e) => (e['score'] as num).toDouble()).reduce((a, b) => a + b) / submissions.length;

      // Top users
      final topUsersResponse = await _supabase
          .from('exam_submissions')
          .select('user_id, score, users(email)')
          .order('score', ascending: false)
          .limit(5);

      final topUsers = List<Map<String, dynamic>>.from(topUsersResponse);

      // Recent issues
      final issuesResponse = await _supabase
          .from('user_issues')
          .select('*, users(email)')
          .order('created_at', ascending: false)
          .limit(10);

      final recentIssues = List<Map<String, dynamic>>.from(issuesResponse);

      setState(() {
        _totalUsers = usersCount.count ?? 0;
        _activeUsers = activeCount.count ?? 0;
        _totalSubmissions = submissions.length;
        _avgScore = avgScore;
        _topUsers = topUsers;
        _recentIssues = recentIssues;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ระบบติดตามผู้ใช้'),
        backgroundColor: Colors.indigo,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'ผู้ใช้ทั้งหมด',
                            _totalUsers.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'ผู้ใช้ Active',
                            _activeUsers.toString(),
                            Icons.person_check,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'ข้อสอบที่ทำ',
                            _totalSubmissions.toString(),
                            Icons.assignment,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'คะแนนเฉลี่ย',
                            _avgScore.toStringAsFixed(1),
                            Icons.analytics,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ผู้ใช้ที่มีคะแนนสูงสุด',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_topUsers.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('ยังไม่มีข้อมูล'),
                        ),
                      )
                    else
                      ..._topUsers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final user = entry.value;
                        final email = user['users']?['email'] ?? 'Unknown';
                        final score = user['score'] ?? 0;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: index == 0
                                  ? Colors.amber
                                  : index == 1
                                      ? Colors.grey
                                      : Colors.brown,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(email),
                            trailing: Text(
                              '$score คะแนน',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ปัญหาที่รายงาน',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const IssueReportScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('ดูทั้งหมด'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_recentIssues.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('ไม่มีปัญหาที่รายงาน'),
                        ),
                      )
                    else
                      ..._recentIssues.take(5).map((issue) {
                        final email = issue['users']?['email'] ?? 'Unknown';
                        final description = issue['description'] ?? '';
                        final status = issue['status'] ?? 'pending';

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              status == 'resolved'
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: status == 'resolved'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            title: Text(email),
                            subtitle: Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Chip(
                              label: Text(status),
                              backgroundColor: status == 'resolved'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class IssueReportScreen extends StatefulWidget {
  const IssueReportScreen({super.key});

  @override
  State<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends State<IssueReportScreen> {
  final _supabase = Supabase.instance.client;
  final _descriptionController = TextEditingController();

  Future<void> _submitIssue() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาระบุรายละเอียดปัญหา')),
      );
      return;
    }

    try {
      await _supabase.from('user_issues').insert({
        'user_id': user.id,
        'description': _descriptionController.text,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รายงานปัญหาสำเร็จ')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายงานปัญหา')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'อธิบายปัญหาที่พบ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'ระบุรายละเอียดปัญหา...',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitIssue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.indigo,
              ),
              child: const Text('ส่งรายงาน', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
