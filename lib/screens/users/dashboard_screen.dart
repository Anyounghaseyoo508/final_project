import 'package:flutter/material.dart';
import 'Vocabulary Learning/vocab_list_screen.dart'; // ตรวจสอบ path ให้ถูกต้องตามโครงสร้างโฟลเดอร์ของคุณ
import 'Exam Practice/exam_list_screen.dart';
import 'Exam Practice/study_history_screen.dart';

class UserDashboardScreen extends StatelessWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ส่วนที่ 1: Header & Profile (Scope 1.3.5.2, 1.3.5.3)
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 220,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.shade700,
                      Colors.blueAccent.shade400,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.person,
                          size: 55,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Welcome back, User!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "เป้าหมายวันนี้: เรียนรู้ 20 คำศัพท์ใหม่",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ส่วนที่ 2: Statistics (Scope 1.3.4.3)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ความคืบหน้าการเรียน",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard(
                        "คำศัพท์ที่รู้",
                        "1,250",
                        Colors.orange,
                        Icons.menu_book_rounded,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        "คะแนนเฉลี่ย",
                        "750",
                        Colors.blue,
                        Icons.insights_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ส่วนที่ 3: Analysis Card (Scope 1.3.4.4)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildAnalysisCard(context),
            ),
          ),

          // ส่วนที่ 4: Quick Menu Grid (Scope 1.3.3, 1.3.4.1)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
              ),
              delegate: SliverChildListDelegate([
                _buildMenuButton(
                  context,
                  "คลังคำศัพท์",
                  "เรียนรู้ตามระดับ CEFR",
                  Icons.collections_bookmark_rounded,
                  Colors.green,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VocabListScreen(),
                    ),
                  ),
                ),
                _buildMenuButton(
                  context,
                  "ข้อสอบ TOEIC",
                  "จำลองสถานการณ์จริง",
                  Icons.assignment_rounded,
                  Colors.blue,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExamListScreen(),
                      ),
                    );
                  }, // เชื่อมต่อหน้าข้อสอบในภายหลัง
                ),
                _buildMenuButton(
                  context,
                  "มินิเกม",
                  "ทบทวนแบบสนุกๆ",
                  Icons.videogame_asset_rounded,
                  Colors.purple,
                  () {}, // เชื่อมต่อหน้าเกมในภายหลัง
                ),
                _buildMenuButton(
                  context,
                  "ประวัติการเรียน",
                  "ดูพัฒนาการย้อนหลัง",
                  Icons.history_rounded,
                  Colors.blueGrey,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudyHistoryScreen(),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),

          // ระยะห่างด้านล่าง
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // ฟังก์ชันสร้าง Card สถิติ
  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ฟังก์ชันสร้าง Card วิเคราะห์จุดบกพร่อง
  Widget _buildAnalysisCard(BuildContext context) {
    // เพิ่ม BuildContext เข้ามา
    return Material(
      // หุ้มด้วย Material เพื่อให้ InkWell แสดง Effect
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // เชื่อมต่อไปยังหน้า AiTutorScreen ด้วย Named Route
          Navigator.pushNamed(context, '/ai-tutor');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.white],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.psychology, color: Colors.green.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AI Tutor วิเคราะห์จุดอ่อน",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "คลิกเพื่อรับคำแนะนำการเรียนส่วนตัวจาก AI",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.green.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันสร้างปุ่มเมนูหลัก
  Widget _buildMenuButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
