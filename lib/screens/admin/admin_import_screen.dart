import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // เปลี่ยน import
import 'package:file_picker/file_picker.dart';

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  bool _isImporting = false;
  String _statusMessage = "เลือกไฟล์ JSON เพื่อนำเข้าสู่ Supabase";
  final _supabase = Supabase.instance.client;

  Future<void> _pickAndImportJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        setState(() {
          _isImporting = true;
          _statusMessage = "กำลังอ่านและเตรียมข้อมูล...";
        });

        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        List<dynamic> data = json.decode(content);

        // 1. เตรียมข้อมูลในรูปแบบ List<Map<String, dynamic>>
        // Supabase สามารถรับ List ของ Map เพื่อทำ Bulk Insert ได้เลย
        final List<Map<String, dynamic>> rows = data.map((item) {
          return {
            // ใน Supabase 'id' มักเป็น Auto-increment หรือ UUID 
            // แต่ถ้าอยากใช้ Custom ID แบบเดิม (SET01_P1_Q1) ก็ส่งไปได้
            'custom_id': "${item['testId']}_P${item['part']}_Q${item['questionNo']}",
            'test_id': item['testId'],
            'part': item['part'],
            'question_no': item['questionNo'],
            'question_text': item['questionText'] ?? "",
            'option_a': item['optionA'] ?? "",
            'option_b': item['optionB'] ?? "",
            'option_c': item['optionC'] ?? "",
            'option_d': item['optionD'] ?? "",
            'correct_answer': item['correctAnswer'] ?? "A",
            'explanation': item['explanation'] ?? "",
            'transcript': item['transcript'] ?? "",
            'audio_group_id': item['audioGroupId'] ?? "",
            'audio_url': item['audioUrl'] ?? "",
            'image_url': item['imageUrl'] ?? "",
            // ไม่ต้องใส่ created_at เพราะ DB ทำให้เอง
          };
        }).toList();

        // 2. ยิงข้อมูลเข้า Supabase ทีเดียว (Bulk Insert)
        await _supabase.from('vocabularies').insert(rows);

        setState(() {
          _isImporting = false;
          _statusMessage = "✅ นำเข้าข้อมูลสู่ Supabase สำเร็จ ${rows.length} รายการ";
        });
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _statusMessage = "❌ ข้อผิดพลาด: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI ส่วนใหญ่คงเดิม เปลี่ยนแค่คำอธิบายเล็กน้อย
    return Scaffold(
      appBar: AppBar(title: const Text("Supabase Data Importer")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload, size: 80, color: Colors.teal),
              const SizedBox(height: 20),
              Text(_statusMessage, textAlign: TextAlign.center),
              const SizedBox(height: 30),
              if (_isImporting)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _pickAndImportJson,
                  icon: const Icon(Icons.upload),
                  label: const Text("Import to Supabase"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}