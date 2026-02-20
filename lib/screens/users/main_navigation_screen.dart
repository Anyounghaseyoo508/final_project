import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'Vocabulary Learning/vocab_list_screen.dart';
import 'Vocabulary Learning/bookmark_list_screen.dart';
import 'Exam Practice/exam_list_screen.dart';

enum NavTab { vocab, bookmark, dashboard, exam, profile }

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  NavTab _currentTab = NavTab.dashboard;
  final _supabase = Supabase.instance.client;

  int get _selectedIndex => _currentTab.index;

  // 1. สร้าง Map สำหรับชื่อหัวข้อใน AppBar ตามหน้าปัจจุบัน
  final Map<NavTab, String> _titles = {
    NavTab.vocab: "คลังคำศัพท์",
    NavTab.bookmark: "คำศัพท์ที่บันทึกไว้",
    NavTab.dashboard: "หน้าหลัก / Dashboard",
    NavTab.exam: "ชุดข้อสอบ TOEIC",
    NavTab.profile: "โปรไฟล์ผู้ใช้งาน",
  };

  final List<Widget> _screens = [
    const VocabListScreen(),
    const BookmarkListScreen(),
    const UserDashboardScreen(),
    const ExamListScreen(),
    const ProfileScreen(),
  ];

  void _onTabChanged(NavTab tab) {
    setState(() {
      _currentTab = tab;
    });
  }

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      // 2. ใส่ AppBar ไว้ที่นี่จุดเดียว จะไม่มีปุ่มย้อนกลับมากวนใจใน Tab หลัก
      appBar: AppBar(
        title: Text(_titles[_currentTab]!, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent.shade700),
              accountName: Text(
                user?.userMetadata?['full_name'] ?? "User Name",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user?.email ?? "user@example.com"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("หน้าหลัก"),
              onTap: () {
                _onTabChanged(NavTab.dashboard);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology),
              title: const Text("AI Tutor"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/ai-tutor'); // AI Tutor เปิดหน้าใหม่ มีปุ่มย้อนกลับได้ปกติ
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("ออกจากระบบ", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
      
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => _onTabChanged(NavTab.values[index]),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'คลังศัพท์'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'ที่บันทึกไว้'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'หน้าหลัก'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'ทำข้อสอบ'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
        ],
      ),
    );
  }
}