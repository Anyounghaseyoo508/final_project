import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamListController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ดึงรายการ Test ID เฉพาะที่ is_published = true เท่านั้น
  Future<List<int>> getTestList() async {
    final response = await _supabase
        .from('exam_sets')           // ← เปลี่ยนจาก practice_test → exam_sets
        .select('test_id')
        .eq('is_published', true)    // ← filter เฉพาะที่เผยแพร่แล้ว
        .order('test_id', ascending: true);

    return (response as List)
        .map((item) => item['test_id'] as int)
        .toList();                   // ไม่ต้อง toSet() แล้ว เพราะ exam_sets มี test_id เป็น PK (ไม่ซ้ำอยู่แล้ว)
  }
}
