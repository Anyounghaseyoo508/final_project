import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  final _emailRegex = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');

  String? _avatarUrl;
  String _displayName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('users')
          .select('display_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _displayName = response?['display_name'] ?? user.email ?? '';
        _avatarUrl = response?['avatar_url'];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Uint8List bytes = await pickedFile.readAsBytes();

      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      await _supabase.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'avatar_url': publicUrl,
      });

      if (!mounted) return;
      setState(() {
        _avatarUrl = publicUrl;
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปเดตรูปโปรไฟล์สำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _updateDisplayName() async {
    final controller = TextEditingController(text: _displayName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขชื่อ'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'display_name': result,
      });

      if (!mounted) return;
      setState(() => _displayName = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปเดตชื่อสำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _changeEmail() async {
    final currentEmail =
        (_supabase.auth.currentUser?.email ?? '').trim().toLowerCase();
    final controller = TextEditingController(
      text: currentEmail,
    );

    final inputEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เปลี่ยนอีเมล'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'อีเมลใหม่'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (inputEmail == null || inputEmail.isEmpty) return;
    final newEmail = inputEmail.trim().toLowerCase();

    if (newEmail == currentEmail) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อีเมลใหม่ต้องไม่ซ้ำกับอีเมลปัจจุบัน')),
      );
      return;
    }

    if (!_emailRegex.hasMatch(newEmail)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รูปแบบอีเมลไม่ถูกต้อง')),
      );
      return;
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('users').upsert({
          'id': user.id,
          'email': newEmail,
          'display_name': _displayName,
          'avatar_url': _avatarUrl,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งลิงก์ยืนยันอีเมลใหม่แล้ว กรุณาเช็กอีเมลและกดยืนยันก่อนใช้งาน'),
        ),
      );
      setState(() {});
    } on AuthException catch (e) {
      if (!mounted) return;
      var message = e.message;
      if (e.message.contains('email_address_invalid')) {
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else if (e.message.contains('already been registered')) {
        message = 'อีเมลนี้ถูกใช้งานแล้ว';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปลี่ยนอีเมลไม่สำเร็จ: $message')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปลี่ยนอีเมลไม่สำเร็จ: $e')));
    }
  }

  Future<void> _changePassword() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เปลี่ยนรหัสผ่าน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'รหัสผ่านใหม่ (อย่างน้อย 6 ตัว)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'ยืนยันรหัสผ่านใหม่',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              final password = passwordController.text;
              final confirm = confirmController.text;
              if (password != confirm) {
                Navigator.pop(context, '__MISMATCH__');
                return;
              }
              Navigator.pop(context, password);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (newPassword == null) return;
    if (newPassword == '__MISMATCH__') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยืนยันรหัสผ่านไม่ตรงกัน')),
      );
      return;
    }
    if (newPassword.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร')),
      );
      return;
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เปลี่ยนรหัสผ่านสำเร็จ')));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปลี่ยนรหัสผ่านไม่สำเร็จ: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เปลี่ยนรหัสผ่านไม่สำเร็จ: $e')));
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันลบบัญชีถาวร'),
        content: const Text('บัญชีและข้อมูลของคุณจะถูกลบถาวร คุณแน่ใจหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบถาวร'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.rpc('delete_my_account');
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('users')
            .update({'is_active': false})
            .eq('id', user.id);
        await _supabase.auth.signOut();
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _supabase.auth.currentUser?.email ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('ชื่อที่แสดง'),
                    subtitle: Text(_displayName),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _updateDisplayName,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('อีเมล'),
                    subtitle: Text(userEmail),
                    trailing: TextButton(
                      onPressed: _changeEmail,
                      child: const Text('เปลี่ยน'),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('รหัสผ่าน'),
                    subtitle: const Text('เปลี่ยนรหัสผ่านบัญชี'),
                    trailing: TextButton(
                      onPressed: _changePassword,
                      child: const Text('เปลี่ยน'),
                    ),
                  ),
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'ออกจากระบบ',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await _supabase.auth.signOut();
                      if (mounted)
                        Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'ลบบัญชีถาวร',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text('ลบข้อมูลบัญชีออกจากระบบ'),
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
    );
  }
}
