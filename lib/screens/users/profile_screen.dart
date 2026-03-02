import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

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

      if (response != null) {
        setState(() {
          _displayName = response['display_name'] ?? user.email ?? '';
          _avatarUrl = response['avatar_url'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _displayName = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final file = File(pickedFile.path);
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('avatars').upload(fileName, file);

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(fileName);

      await _supabase.from('users').update({
        'avatar_url': publicUrl,
      }).eq('id', user.id);

      setState(() {
        _avatarUrl = publicUrl;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัพเดตรูปโปรไฟล์สำเร็จ')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
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
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('users').update({
        'display_name': result,
      }).eq('id', user.id);

      setState(() => _displayName = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัพเดตชื่อสำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _deactivateAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบบัญชี'),
        content: const Text(
          'ระบบจะปิดการใช้งานบัญชีนี้ และคุณจะไม่สามารถเข้าสู่ระบบได้จนกว่าผู้ดูแลระบบจะเปิดใช้งานอีกครั้ง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันลบบัญชี'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('users').update({
        'is_active': false,
      }).eq('id', user.id);

      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบบัญชีไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์'),
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
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
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
                    subtitle: Text(_supabase.auth.currentUser?.email ?? ''),
                  ),
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('ตั้งค่า'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('ออกจากระบบ',
                        style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await _supabase.auth.signOut();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('ลบบัญชี',
                        style: TextStyle(color: Colors.red)),
                    subtitle: const Text('ปิดการใช้งานบัญชีนี้'),
                    onTap: _deactivateAccount,
                  ),
                ],
              ),
            ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _notificationsEnabled = response['notifications_enabled'] ?? true;
          _soundEnabled = response['sound_enabled'] ?? true;
          _darkMode = response['dark_mode'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_settings').upsert({
        'user_id': user.id,
        key: value,
      });
    } catch (e) {
      debugPrint('Error saving setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('การแจ้งเตือน'),
            subtitle: const Text('รับการแจ้งเตือนจากแอป'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSetting('notifications_enabled', value);
            },
          ),
          SwitchListTile(
            title: const Text('เสียง'),
            subtitle: const Text('เปิด/ปิดเสียงในแอป'),
            value: _soundEnabled,
            onChanged: (value) {
              setState(() => _soundEnabled = value);
              _saveSetting('sound_enabled', value);
            },
          ),
          SwitchListTile(
            title: const Text('โหมดมืด'),
            subtitle: const Text('เปลี่ยนธีมเป็นโหมดมืด'),
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
              _saveSetting('dark_mode', value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('นโยบายความเป็นส่วนตัว'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('เกี่ยวกับแอป'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
