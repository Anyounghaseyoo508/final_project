import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // เปลี่ยนเป็น supabase

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client; // สร้างตัวแปรเรียกใช้งาน
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (res.user != null) {
        // ดึงข้อมูล Role จากตาราง users
        final data = await _supabase
            .from('users')
            .select('role, is_active')
            .eq('id', res.user!.id)
            .single();

        String role = data['role'] ?? 'user';
        final isActive = data['is_active'] != false;

        if (mounted) {
          if (!isActive) {
            await _supabase.auth.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('บัญชีนี้ถูกปิดการใช้งาน กรุณาติดต่อผู้ดูแลระบบ')),
            );
            return;
          }

          if (role == 'admin') {
            Navigator.pushReplacementNamed(context, '/admin_home');
          } else {
            // หากเป็น user ปกติ ให้ไปที่หน้าที่คุณกำหนดไว้ (เช่นหน้าแรก)
            Navigator.pushReplacementNamed(context, '/');
          }
        }
      }
    } on AuthException catch (e) {
      String message = "อีเมลหรือรหัสผ่านไม่ถูกต้อง";
      if (e.message.contains("Invalid login credentials")) {
        message = "อีเมลหรือรหัสผ่านไม่ถูกต้อง";
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เข้าสู่ระบบไม่สำเร็จ: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกอีเมลก่อนกดลืมรหัสผ่าน')),
      );
      return;
    }

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งลิงก์ไม่สำเร็จ: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... โค้ด UI ส่วนเดิมของคุณ (เหมือนเดิมเป๊ะ)
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "VocabBoost Login",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _signIn,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("เข้าสู่ระบบ"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text("ยังไม่มีบัญชี? สมัครสมาชิกใหม่"),
            ),
            TextButton(
              onPressed: _forgotPassword,
              child: const Text("ลืมรหัสผ่าน"),
            ),
          ],
        ),
      ),
    );
  }
}
