import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("โปรไฟล์ผู้ใช้งาน"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.userMetadata?['full_name'] ?? "ชื่อผู้ใช้งาน",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text(user?.email ?? "email@example.com", style: TextStyle(color: Colors.grey[600])),
          ),
          const SizedBox(height: 32),
          const Text("การตั้งค่าบัญชี", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text("แก้ไขโปรไฟล์"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("การแจ้งเตือน"),
            trailing: Switch(value: true, onChanged: (v) {}),
          ),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text("ภาษาของแอป"),
            trailing: Text("ภาษาไทย"),
          ),
          const SizedBox(height: 20),
          const Text("ความปลอดภัย", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("เปลี่ยนรหัสผ่าน"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("ออกจากระบบ", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}