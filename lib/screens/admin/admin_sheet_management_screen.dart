import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 1. เปลี่ยน import

class AdminSheetManagementScreen extends StatelessWidget {
  const AdminSheetManagementScreen({super.key});

  // สร้าง instance ของ Supabase Client
  static final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("จัดการชีทสรุป (Supabase)"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // 2. ใช้ .stream() ของ Supabase เพื่อดึงข้อมูลแบบ Real-time
        // ระบุ primaryKey เพื่อให้ Stream ทำงานได้ถูกต้อง
        stream: _supabase
            .from('sheets')
            .stream(primaryKey: ['id'])
            .order('title'), 
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
          }
          
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data!;

          if (docs.isEmpty) {
            return const Center(child: Text("ยังไม่มีชีทสรุปในระบบ"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(data['title'] ?? 'ไม่มีชื่อเรื่อง'),
                subtitle: Text(data['category'] ?? 'ไม่มีหมวดหมู่'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () => _confirmDelete(context, data['id']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () {
          // ในอนาคตคุณสามารถใช้ supabase.storage เพื่ออัปโหลดไฟล์ PDF ได้ที่นี่
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ระบบอัปโหลดไฟล์ไปยัง Supabase Storage กำลังพัฒนา...")),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ฟังก์ชันลบข้อมูล
  Future<void> _confirmDelete(BuildContext context, dynamic id) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: const Text("คุณต้องการลบชีทสรุปนี้ใช่หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ยกเลิก")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("ลบ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 3. คำสั่งลบข้อมูลใน Supabase
        await _supabase.from('sheets').delete().eq('id', id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ลบข้อมูลสำเร็จ")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("ลบไม่สำเร็จ: $e")),
          );
        }
      }
    }
  }
}