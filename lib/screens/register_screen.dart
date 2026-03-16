import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  int _strength = 0;

  static const int _minLen = 8;

  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const Color _blue = Color(0xFF1A56DB);
  static const Color _bg = Color(0xFFF0F5FF);
  static const Color _textPri = Color(0xFF111827);
  static const Color _textMut = Color(0xFF6B7280);
  static const Color _border = Color(0xFFD1D5DB);
  static const Color _inputBg = Color(0xFFFAFBFF);
  static const Color _error = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
    _passwordController.addListener(_calcStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _calcStrength() {
    final p = _passwordController.text;
    var s = 0;
    if (p.length >= _minLen) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s++;
    setState(() => _strength = s);
  }

  Color _sColor() {
    switch (_strength) {
      case 1:
        return const Color(0xFFDC2626);
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFF16A34A);
      case 4:
        return _blue;
      default:
        return _border;
    }
  }

  String _sLabel() {
    switch (_strength) {
      case 1:
        return 'อ่อนมาก';
      case 2:
        return 'พอใช้';
      case 3:
        return 'ดี';
      case 4:
        return 'แข็งแกร่ง';
      default:
        return '';
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'display_name': _nameController.text.trim()},
      );

      final User? user = res.user;

      // ✅ ถ้า identities ว่าง = email ซ้ำใน Supabase Auth (ไม่ throw error แต่คืน user เดิม)
      if (user == null || user.identities == null || user.identities!.isEmpty) {
        if (mounted) _showSnackBar('อีเมลนี้ถูกใช้งานแล้ว', isError: true);
        return;
      }

      // ✅ ใช้ upsert แทน insert เพื่อป้องกัน 409 Conflict
      await _supabase.from('users').upsert({
        'id': user.id,
        'email': _emailController.text.trim(),
        'display_name': _nameController.text.trim(),
        'role': 'user',
        'is_active': true,
      });

      if (mounted) {
        _showSnackBar('สมัครสมาชิกสำเร็จ! ยินดีต้อนรับ');
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      }
    } on AuthException catch (e) {
      if (mounted) {
        var msg = e.message;
        if (e.statusCode == '429') msg = 'ส่งคำขอถี่เกินไป กรุณารอสักครู่';
        if (e.statusCode == '422' ||
            e.message.contains('registered') ||
            e.message.contains('already')) {
          msg = 'อีเมลนี้ถูกใช้งานแล้ว';
        }
        _showSnackBar(msg, isError: true);
      }
    } catch (_) {
      if (mounted) _showSnackBar('เกิดข้อผิดพลาด กรุณาลองใหม่', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? _error : _blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 32),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'สร้างบัญชีใหม่',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'กรอกข้อมูลด้านล่างเพื่อเริ่มต้นใช้งาน',
                    style: TextStyle(fontSize: 13, color: _textMut),
                  ),
                  const SizedBox(height: 28),
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
                          _label('ชื่อผู้ใช้งาน'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: _textPri, fontSize: 14),
                            decoration: _deco(hint: 'ชื่อที่ต้องการแสดงในแอป'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'กรุณากรอกชื่อผู้ใช้งาน';
                              }
                              if (v.trim().length < 2) {
                                return 'ชื่อต้องมีอย่างน้อย 2 ตัวอักษร';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _label('อีเมล'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: _textPri, fontSize: 14),
                            decoration: _deco(hint: 'example@email.com'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'กรุณากรอกอีเมล';
                              }
                              if (!RegExp(
                                r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                              ).hasMatch(v.trim())) {
                                return 'รูปแบบอีเมลไม่ถูกต้อง';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _label('รหัสผ่าน'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePass,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: _textPri, fontSize: 14),
                            decoration: _deco(
                              hint: 'อย่างน้อย $_minLen ตัวอักษร',
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _textMut,
                                  size: 19,
                                ),
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'กรุณากรอกรหัสผ่าน';
                              }
                              if (v.length < _minLen) {
                                return 'รหัสผ่านต้องมีอย่างน้อย $_minLen ตัวอักษร';
                              }
                              return null;
                            },
                          ),
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ...List.generate(
                                  4,
                                  (i) => Expanded(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      height: 3,
                                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                                      decoration: BoxDecoration(
                                        color: i < _strength ? _sColor() : _border,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _sLabel(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _sColor(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _hintRow(
                              'อย่างน้อย $_minLen ตัวอักษร',
                              _passwordController.text.length >= _minLen,
                            ),
                            _hintRow(
                              'ตัวพิมพ์ใหญ่ (A-Z)',
                              _passwordController.text.contains(RegExp(r'[A-Z]')),
                            ),
                            _hintRow(
                              'ตัวเลข (0-9)',
                              _passwordController.text.contains(RegExp(r'[0-9]')),
                            ),
                            _hintRow(
                              'อักขระพิเศษ (!@#\$...)',
                              _passwordController.text.contains(
                                RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _label('ยืนยันรหัสผ่าน'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signUp(),
                            style: const TextStyle(color: _textPri, fontSize: 14),
                            decoration: _deco(
                              hint: 'กรอกรหัสผ่านอีกครั้ง',
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: _textMut,
                                  size: 19,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'กรุณายืนยันรหัสผ่าน';
                              }
                              if (v != _passwordController.text) {
                                return 'รหัสผ่านไม่ตรงกัน';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _blue.withOpacity(0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'สร้างบัญชี',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'มีบัญชีแล้ว?',
                        style: TextStyle(color: _textMut, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'เข้าสู่ระบบ',
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
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textPri,
        ),
      );

  Widget _hintRow(String text, bool met) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 13,
              color: met ? const Color(0xFF16A34A) : _border,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: met ? const Color(0xFF16A34A) : _textMut,
              ),
            ),
          ],
        ),
      );

  InputDecoration _deco({required String hint, Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _border, fontSize: 14),
        suffixIcon: suffix,
        filled: true,
        fillColor: _inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11, color: _error),
      );
}