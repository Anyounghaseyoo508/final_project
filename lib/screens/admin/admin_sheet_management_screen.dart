import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSheetManagementScreen extends StatefulWidget {
  const AdminSheetManagementScreen({super.key});
  @override
  State<AdminSheetManagementScreen> createState() => _AdminSheetManagementScreenState();
}

class _AdminSheetManagementScreenState extends State<AdminSheetManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("จัดการเนื้อหา"),
        backgroundColor: Colors.orange, foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf), text: "ชีทสรุป"),
            Tab(icon: Icon(Icons.link_rounded),   text: "แหล่งเรียนรู้"),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: const [_SheetsTab(), _ResourcesTab()]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 : ชีทสรุป
// ─────────────────────────────────────────────────────────────────────────────
class _SheetsTab extends StatelessWidget {
  const _SheetsTab();
  static final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('sheets').stream(primaryKey: ['id']).order('title'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!;
          if (docs.isEmpty) return const Center(child: Text("ยังไม่มีชีทสรุปในระบบ"));
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) {
              final data = docs[i];
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(data['title'] ?? 'ไม่มีชื่อเรื่อง'),
                subtitle: Text(data['category'] ?? 'ไม่มีหมวดหมู่'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'แก้ไข', icon: const Icon(Icons.edit_rounded, color: Colors.orange, size: 20), onPressed: () => _showEditSheet(context, data)),
                  IconButton(tooltip: 'ลบ',    icon: const Icon(Icons.delete_rounded, color: Colors.grey, size: 20),  onPressed: () => _confirmDelete(context, data['id'])),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ระบบอัปโหลดไฟล์กำลังพัฒนา..."))),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context, Map<String, dynamic> data) async {
    final titleCtrl    = TextEditingController(text: data['title'] ?? '');
    final categoryCtrl = TextEditingController(text: data['category'] ?? '');
    bool saving = false;
    await showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: const Row(children: [Icon(Icons.edit_rounded, color: Colors.orange, size: 20), SizedBox(width: 8), Text("แก้ไขชีทสรุป")]),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl("ชื่อเรื่อง *"), const SizedBox(height: 6),
          TextField(controller: titleCtrl, decoration: _deco("ชื่อชีทสรุป"), textInputAction: TextInputAction.next),
          const SizedBox(height: 12),
          _lbl("หมวดหมู่"), const SizedBox(height: 6),
          TextField(controller: categoryCtrl, decoration: _deco("เช่น Grammar")),
          const SizedBox(height: 8),
        ])),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
            label: const Text("บันทึก", style: TextStyle(color: Colors.white)),
            onPressed: saving ? null : () async {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("กรุณากรอกชื่อเรื่อง"))); return; }
              set(() => saving = true);
              try {
                await _supabase.from('sheets').update({'title': t, 'category': categoryCtrl.text.trim()}).eq('id', data['id']);
                if (ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("แก้ไขข้อมูลสำเร็จ"))); }
              } catch (e) { set(() => saving = false); if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("ผิดพลาด: \$e"))); }
            },
          ),
        ],
      )),
    );
  }

  Future<void> _confirmDelete(BuildContext context, dynamic id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("ยืนยันการลบ"), content: const Text("ต้องการลบชีทสรุปนี้ใช่หรือไม่?"),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ลบ", style: TextStyle(color: Colors.red)))],
    ));
    if (ok == true) {
      try {
        await _supabase.from('sheets').delete().eq('id', id);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ลบข้อมูลสำเร็จ")));
      } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ลบไม่สำเร็จ: \$e"))); }
    }
  }

  static Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600));
  static InputDecoration _deco(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(fontSize: 12, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 : แหล่งเรียนรู้
// ─────────────────────────────────────────────────────────────────────────────
class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab();
  static final _supabase = Supabase.instance.client;

  static const _typeMap = {
    'youtube': (Icons.play_circle_fill_rounded, Color(0xFFFF0000)),
    'article': (Icons.article_rounded,          Color(0xFF1A56DB)),
    'website': (Icons.language_rounded,         Color(0xFF0891B2)),
    'other':   (Icons.link_rounded,             Color(0xFF7C3AED)),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.orange.withOpacity(0.08),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 15, color: Colors.orange), SizedBox(width: 8),
            Expanded(child: Text("กด ⭐ เพื่อเลือกโชว์บน Dashboard (สูงสุด 6 รายการ)", style: TextStyle(fontSize: 12, color: Colors.orange))),
          ]),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('learning_resources').stream(primaryKey: ['id']).order('is_pinned', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              if (items.isEmpty) return const Center(child: Text("ยังไม่มีแหล่งเรียนรู้ในระบบ"));
              final pinnedCount = items.where((e) => e['is_pinned'] == true).length;
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 80, top: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, i) {
                  final item     = items[i];
                  final type     = (item['type'] as String?) ?? 'other';
                  final isPinned = item['is_pinned'] == true;
                  // นับจำนวนรูป
                  final rawImgs  = item['image_urls'];
                  final imgCount = rawImgs is List ? rawImgs.length : 0;
                  final (icon, color) = _typeMap[type] ?? _typeMap['other']!;
                  return ListTile(
                    leading: GestureDetector(
                      onTap: () => _togglePin(context, item, isPinned, pinnedCount),
                      child: Tooltip(
                        message: isPinned ? 'ซ่อนจาก Dashboard' : 'โชว์บน Dashboard',
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: isPinned ? Colors.orange.withOpacity(0.12) : Colors.grey.withOpacity(0.08), shape: BoxShape.circle),
                          child: Icon(isPinned ? Icons.star_rounded : Icons.star_outline_rounded, color: isPinned ? Colors.orange : Colors.grey, size: 22),
                        ),
                      ),
                    ),
                    title: Row(children: [
                      Icon(icon, color: color, size: 14), const SizedBox(width: 5),
                      Expanded(child: Text(item['title'] ?? 'ไม่มีชื่อ', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isPinned ? FontWeight.w700 : FontWeight.w500))),
                    ]),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // badges แถวบน
                      if (isPinned || imgCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            if (isPinned) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: const Text("Dashboard", style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w700)),
                            ),
                            if (isPinned && imgCount > 0) const SizedBox(width: 4),
                            if (imgCount > 0) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFE0F7FA), borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.photo_library_rounded, size: 9, color: Color(0xFF0891B2)),
                                const SizedBox(width: 3),
                                Text('$imgCount รูป', style: const TextStyle(fontSize: 9, color: Color(0xFF0891B2), fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ]),
                        ),
                      if ((item['description'] as String?)?.isNotEmpty == true)
                        Text(item['description'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      Text(item['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'แก้ไข', icon: const Icon(Icons.edit_rounded, color: Colors.orange, size: 20), onPressed: () => _showEditDialog(context, item)),
                      IconButton(tooltip: 'ลบ',    icon: const Icon(Icons.delete_rounded, color: Colors.grey, size: 20),  onPressed: () => _confirmDelete(context, item['id'])),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add_link_rounded, color: Colors.white),
        label: const Text("เพิ่มแหล่งเรียนรู้", style: TextStyle(color: Colors.white)),
        onPressed: () => _showAddDialog(context),
      ),
    );
  }

  Future<void> _togglePin(BuildContext context, Map<String, dynamic> item, bool isPinned, int pinnedCount) async {
    if (!isPinned && pinnedCount >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("โชว์ได้สูงสุด 6 รายการ กรุณายกเลิกรายการอื่นก่อน"), backgroundColor: Colors.deepOrange));
      return;
    }
    try {
      await _supabase.from('learning_resources').update({'is_pinned': !isPinned}).eq('id', item['id']);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!isPinned ? "📌 เพิ่มบน Dashboard แล้ว" : "ซ่อนจาก Dashboard แล้ว"), duration: const Duration(seconds: 1)));
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ผิดพลาด: \$e"))); }
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await _showResourceDialog(context: context, title: "เพิ่มแหล่งเรียนรู้",
      onSave: (data) async => await _supabase.from('learning_resources').insert(data));
  }

  Future<void> _showEditDialog(BuildContext context, Map<String, dynamic> item) async {
    await _showResourceDialog(context: context, title: "แก้ไขแหล่งเรียนรู้", initialData: item,
      onSave: (data) async => await _supabase.from('learning_resources').update(data).eq('id', item['id']));
  }

  Future<void> _showResourceDialog({
    required BuildContext context,
    required String title,
    Map<String, dynamic>? initialData,
    required Future<void> Function(Map<String, dynamic>) onSave,
  }) async {
    final titleCtrl  = TextEditingController(text: initialData?['title'] ?? '');
    final urlCtrl    = TextEditingController(text: initialData?['url'] ?? '');
    final descCtrl   = TextEditingController(text: initialData?['description'] ?? '');
    final detailCtrl = TextEditingController(text: initialData?['detail'] ?? '');
    String selectedType = initialData?['type'] ?? 'youtube';

    // โหลด existing image urls
    final rawExisting = initialData?['image_urls'];
    List<String> existingUrls = rawExisting is List
        ? rawExisting.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : [];

    List<_PickedImage> newImages = [];   // รูปใหม่ที่ยังไม่ได้อัปโหลด
    bool isUploading = false;
    bool isSaving    = false;

    final picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final totalCount = existingUrls.length + newImages.length;
        return AlertDialog(
          title: Row(children: [
            Icon(initialData == null ? Icons.add_link_rounded : Icons.edit_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8), Text(title),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── ประเภท ─────────────────────────────────────────────
              _lbl("ประเภท"), const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: _typeMap.keys.map((t) {
                final selected = selectedType == t;
                final (icon, color) = _typeMap[t]!;
                return ChoiceChip(
                  avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
                  label: Text(_typeLabel(t)), selected: selected, selectedColor: color,
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontSize: 12),
                  onSelected: (_) => set(() => selectedType = t),
                );
              }).toList()),
              const SizedBox(height: 14),

              // ── ชื่อเรื่อง ──────────────────────────────────────────
              _lbl("ชื่อเรื่อง *"), const SizedBox(height: 6),
              TextField(controller: titleCtrl, decoration: _deco("เช่น TOEIC Listening Tips"), textInputAction: TextInputAction.next),
              const SizedBox(height: 12),

              // ── URL ────────────────────────────────────────────────
              _lbl("URL / ลิงก์ *"), const SizedBox(height: 6),
              TextField(controller: urlCtrl, decoration: _deco("https://..."), keyboardType: TextInputType.url, textInputAction: TextInputAction.next),
              const SizedBox(height: 12),

              // ── คำอธิบายสั้น ────────────────────────────────────────
              _lbl("คำอธิบายสั้น (แสดงบน card)"), const SizedBox(height: 6),
              TextField(controller: descCtrl, decoration: _deco("สรุปสั้นๆ 1-2 บรรทัด"), maxLines: 2),
              const SizedBox(height: 12),

              // ── รายละเอียดยาว ──────────────────────────────────────
              _lbl("รายละเอียด (แสดงหน้า detail)"), const SizedBox(height: 6),
              TextField(controller: detailCtrl, decoration: _deco("อธิบายเนื้อหาเพิ่มเติม..."), maxLines: 5, minLines: 3),
              const SizedBox(height: 14),

              // ── รูปภาพ ─────────────────────────────────────────────
              Row(children: [
                _lbl("รูปภาพ ($totalCount รูป)"),
                const Spacer(),
                if (totalCount > 0)
                  Text("เลื่อนดูและกด × เพื่อลบ", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 8),

              // ── Grid preview รูป ────────────────────────────────────
              if (totalCount > 0)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemBuilder: (_, i) {
                    final isExisting = i < existingUrls.length;
                    return Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isExisting
                            ? Image.network(existingUrls[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_rounded, color: Colors.grey)))
                            : Image.memory(newImages[i - existingUrls.length].bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      ),
                      // badge "ใหม่"
                      if (!isExisting)
                        Positioned(left: 4, top: 4, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(6)),
                          child: const Text("ใหม่", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        )),
                      // ปุ่มลบ
                      Positioned(right: 4, top: 4, child: GestureDetector(
                        onTap: () {
                          set(() {
                            if (isExisting) existingUrls.removeAt(i);
                            else newImages.removeAt(i - existingUrls.length);
                          });
                        },
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      )),
                    ]);
                  },
                ),

              const SizedBox(height: 8),
              // ปุ่มเพิ่มรูป
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.orange, size: 18),
                  label: Text(
                    totalCount == 0 ? "เลือกรูปภาพ" : "เพิ่มรูปภาพ",
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                  onPressed: (isSaving || isUploading) ? null : () async {
                    // pickMultiImage ให้เลือกหลายรูปพร้อมกัน
                    final picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1200);
                    if (picked.isNotEmpty) {
                      final loaded = await Future.wait(picked.map((f) async {
                        final bytes = await f.readAsBytes();
                        final ext   = f.path.split('.').last.toLowerCase();
                        return _PickedImage(file: f, bytes: bytes, ext: ext);
                      }));
                      set(() => newImages.addAll(loaded));
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ])),
          ),
          actions: [
            TextButton(onPressed: (isSaving || isUploading) ? null : () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              icon: (isSaving || isUploading)
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: Text(
                isUploading ? "กำลังอัปโหลด ${existingUrls.length + 1}/${existingUrls.length + newImages.length} ..." : "บันทึก",
                style: const TextStyle(color: Colors.white),
              ),
              onPressed: (isSaving || isUploading) ? null : () async {
                final t = titleCtrl.text.trim();
                final u = urlCtrl.text.trim();
                if (t.isEmpty || u.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("กรุณากรอกชื่อเรื่องและ URL")));
                  return;
                }
                set(() => isSaving = true);
                try {
                  // ── อัปโหลดรูปใหม่ทีละรูป ──────────────────────────
                  final uploadedUrls = <String>[];
                  for (int i = 0; i < newImages.length; i++) {
                    set(() => isUploading = true);
                    final img       = newImages[i];
                    final bytes     = img.bytes;  // bytes โหลดไว้แล้วตอน pick
                    final ext       = img.ext;  // ext เก็บไว้แล้วใน _PickedImage
                    final fileName  = 'resource_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
                    await _supabase.storage.from('resource-images').uploadBinary(
                      fileName, bytes,
                      fileOptions: FileOptions(contentType: 'image/\${ext}', upsert: true),
                    );
                    uploadedUrls.add(_supabase.storage.from('resource-images').getPublicUrl(fileName));
                  }
                  set(() => isUploading = false);

                  // รวม existing (ที่ยังไม่ถูกลบ) + ใหม่
                  final finalUrls = [...existingUrls, ...uploadedUrls];

                  await onSave({
                    'title':       t,
                    'url':         u,
                    'description': descCtrl.text.trim(),
                    'detail':      detailCtrl.text.trim(),
                    'image_urls':  finalUrls,   // ← array
                    'type':        selectedType,
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(initialData == null ? "เพิ่มแหล่งเรียนรู้สำเร็จ" : "แก้ไขข้อมูลสำเร็จ")));
                  }
                } catch (e) {
                  set(() { isSaving = false; isUploading = false; });
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("ผิดพลาด: \$e")));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _confirmDelete(BuildContext context, dynamic id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("ยืนยันการลบ"), content: const Text("ต้องการลบแหล่งเรียนรู้นี้ใช่หรือไม่?"),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ลบ", style: TextStyle(color: Colors.red)))],
    ));
    if (ok == true) {
      try {
        await _supabase.from('learning_resources').delete().eq('id', id);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ลบข้อมูลสำเร็จ")));
      } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ลบไม่สำเร็จ: \$e"))); }
    }
  }

  static Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600));
  static String _typeLabel(String t) => const {'youtube':'YouTube','article':'บทความ','website':'เว็บไซต์','other':'อื่นๆ'}[t] ?? t;
  static InputDecoration _deco(String h) => InputDecoration(hintText: h, hintStyle: const TextStyle(fontSize: 12, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true);
}

// ── Helper class สำหรับรูปที่เลือกแล้ว (Web-compatible) ──────────────────────
class _PickedImage {
  final dynamic    file;   // XFile (ไม่ใช้ตรงๆ บน web)
  final Uint8List  bytes;  // ใช้ bytes แทน File path
  final String     ext;

  const _PickedImage({required this.file, required this.bytes, required this.ext});
}