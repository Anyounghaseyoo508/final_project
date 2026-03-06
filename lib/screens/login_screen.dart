import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Theme ──
  static const Color _blue      = Color(0xFF1A56DB);
  static const Color _blueLight = Color(0xFF3B82F6);
  static const Color _bg        = Color(0xFFF0F5FF);
  static const Color _textPri   = Color(0xFF111827);
  static const Color _textMut   = Color(0xFF6B7280);
  static const Color _border    = Color(0xFFD1D5DB);
  static const Color _inputBg   = Color(0xFFFAFBFF);
  static const Color _error     = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (res.user != null) {
        final data = await _supabase
            .from('users')
            .select('role, is_active')
            .eq('id', res.user!.id)
            .single();

        final String role = data['role'] ?? 'user';
        final bool isActive = data['is_active'] != false;

        if (mounted) {
          if (!isActive) {
            await _supabase.auth.signOut();
            _showSnackBar('บัญชีนี้ถูกปิดการใช้งาน กรุณาติดต่อผู้ดูแลระบบ',
                isError: true);
            return;
          }
          Navigator.pushNamedAndRemoveUntil(
            context,
            role == 'admin' ? '/admin_home' : '/',
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showSnackBar(
          e.message.contains('Invalid login credentials')
              ? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง'
              : e.message,
          isError: true,
        );
      }
    } catch (_) {
      if (mounted)
        _showSnackBar('เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('กรุณากรอกอีเมลก่อนกดลืมรหัสผ่าน', isError: true);
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('รูปแบบอีเมลไม่ถูกต้อง', isError: true);
      return;
    }
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      if (mounted) _showSnackBar('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว ✉️');
    } on AuthException catch (e) {
      if (mounted)
        _showSnackBar('ส่งลิงก์ไม่สำเร็จ: ${e.message}', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: isError ? _error : _blue,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──
                    Center(
                      child: Image.asset(
                        'assets/images/vocabboost_logo_v3.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'เข้าสู่ระบบเพื่อเริ่มใช้งาน',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: _textMut),
                    ),
                    const SizedBox(height: 36),

                    // ── Form card ──
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withOpacity(0.07),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email
                            _label('อีเมล'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                  color: _textPri, fontSize: 14),
                              decoration:
                                  _deco(hint: 'example@email.com'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'กรุณากรอกอีเมล';
                                if (!RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(v.trim()))
                                  return 'รูปแบบอีเมลไม่ถูกต้อง';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password
                            _label('รหัสผ่าน'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _signIn(),
                              style: const TextStyle(
                                  color: _textPri, fontSize: 14),
                              decoration: _deco(
                                hint: '••••••••',
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _textMut,
                                    size: 19,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'กรุณากรอกรหัสผ่าน';
                                return null;
                              },
                            ),

                            // Forgot
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 2)),
                                child: const Text(
                                  'ลืมรหัสผ่าน?',
                                  style: TextStyle(
                                    color: _blueLight,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Button
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      _blue.withOpacity(0.5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        'เข้าสู่ระบบ',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('ยังไม่มีบัญชี?',
                            style:
                                TextStyle(color: _textMut, fontSize: 13)),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6)),
                          child: const Text(
                            'สมัครสมาชิก',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPri),
      );

  InputDecoration _deco({required String hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: _border, fontSize: 14),
        suffixIcon: suffix,
        filled: true,
        fillColor: _inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _blue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _error, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 11, color: _error),
      );
}