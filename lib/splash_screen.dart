import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SplashScreen — หน้าแรกที่เปิดขึ้นมาทุกครั้งที่เปิดแอป
// หน้าที่: ตรวจว่ามี session ค้างอยู่ไหม แล้ว redirect ไปหน้าที่ถูกต้อง
// ผู้ใช้จะเห็นหน้านี้แค่ชั่วครู่ (loading spinner) แล้วหายไปเลย
// ──────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // เรียกตรวจ session ทันทีที่หน้านี้โหลด
    _checkSession();
  }

  Future<void> _checkSession() async {
    // หน่วงเล็กน้อยให้ Flutter render UI ก่อน (ป้องกัน navigator error)
    await Future.delayed(const Duration(milliseconds: 300));

    final supabase = Supabase.instance.client;

    // ── ตรวจว่ามี session ค้างอยู่ไหม ──────────────────────────────────────
    // currentSession จะ return null ถ้าไม่เคย login หรือ logout ไปแล้ว
    // ถ้ามี session Supabase จะ auto-refresh token ให้อัตโนมัติ
    final session = supabase.auth.currentSession;
    
    if (!mounted) return;

    if (session == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    // ── มี session → ดึง role และ is_active จากตาราง users ─────────────────
    try {
      final data = await supabase
          .from('users')
          .select('role, is_active')
          .eq('id', session.user.id)
          .single();

      final role = data['role'] ?? 'user';
      final isActive = data['is_active'] != false;

      if (!mounted) return;

      // ── บัญชีถูกปิด → logout แล้วไป Login ─────────────────────────────────
      if (!isActive) {
        await supabase.auth.signOut();
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      if (role == 'admin') {
        await supabase.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บัญชีแอดมินต้องใช้งานผ่าน Admin Web'),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      // ถ้าดึงข้อมูลไม่ได้ (เช่น ไม่มี internet) → ไปหน้า Login
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI ของ SplashScreen — แค่ loading spinner ตรงกลาง
    // ผู้ใช้จะเห็นแค่ชั่วครู่แล้วหายไปเลย
    return const Scaffold(
      backgroundColor: Color(0xFF1E3A5F), // สีเดียวกับ Admin sidebar
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Icon(Icons.school_rounded, size: 64, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'VocabBoost',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            // Loading spinner
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}