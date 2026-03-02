import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamSet {
  final int testId;
  final String title;

  ExamSet({required this.testId, required this.title});

  factory ExamSet.fromMap(Map<String, dynamic> map) {
    return ExamSet(
      testId: map['test_id'] as int,
      title: map['title'] as String? ?? 'TOEIC Practice Test #${map['test_id']}',
    );
  }
}

class ExamListController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  Future<List<ExamSet>> getTestList() async {
    final response = await _supabase
        .from('exam_sets')
        .select('test_id, title')
        .eq('is_published', true)
        .order('test_id', ascending: true);

    return (response as List)
        .map((item) => ExamSet.fromMap(item))
        .toList();
  }
}
