import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // เปลี่ยนเป็น supabase

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบถ้วน")),
      );
      return;
    }

    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'display_name': _nameController.text.trim()},
      );

      final User? user = res.user;

      if (user != null) {
        // บันทึกข้อมูลลงตาราง users
        await _supabase.from('users').insert({
          'id': user.id,
          'email': _emailController.text.trim(),
          'display_name': _nameController.text.trim(),
          'role': 'user',
          // 'created_at' ปกติในฐานข้อมูล Supabase จะตั้งค่า DEFAULT now() ไว้แล้ว ไม่ต้องส่งไปก็ได้ครับ
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("สมัครสมาชิกสำเร็จ!")));
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } on AuthException catch (e) {
      // แยก Error เฉพาะทางของ Supabase Auth เช่น Rate Limit
      String message = e.message;
      if (e.statusCode == '429') {
        message = "ส่งคำขอถี่เกินไป กรุณารอสักครู่แล้วลองใหม่";
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... โค้ด UI ส่วนเดิมของคุณ
    return Scaffold(
      appBar: AppBar(title: const Text("สมัครสมาชิกใหม่")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "ชื่อผู้ใช้งาน"),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "อีเมล"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "รหัสผ่าน"),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _signUp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("สร้างบัญชี"),
            ),
          ],
        ),
      ),
    );
  }
}
