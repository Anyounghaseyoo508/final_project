import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Resource Model ───────────────────────────────────────────────────────────
class LearningResource {
  final int          id;
  final String       title;
  final String       url;
  final String       description;
  final String       detail;
  final List<String> imageUrls;   // ← หลายรูป
  final String       type;
  final DateTime     createdAt;

  const LearningResource({
    required this.id,
    required this.title,
    required this.url,
    required this.description,
    required this.detail,
    required this.imageUrls,
    required this.type,
    required this.createdAt,
  });

  factory LearningResource.fromMap(Map<String, dynamic> m) {
    // image_urls เก็บเป็น List<String> ใน Supabase (array column)
    final raw = m['image_urls'];
    final List<String> urls;
    if (raw is List) {
      urls = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } else if (raw is String && raw.isNotEmpty) {
      // fallback: ถ้าเป็น string เดี่ยว (migration จากของเก่า)
      urls = [raw];
    } else {
      urls = [];
    }
    return LearningResource(
      id:          (m['id'] as num).toInt(),
      title:       (m['title']       as String?) ?? '',
      url:         (m['url']         as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      detail:      (m['detail']      as String?) ?? '',
      imageUrls:   urls,
      type:        (m['type']        as String?) ?? 'other',
      createdAt:   DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  bool get hasImages => imageUrls.isNotEmpty;
  ResourceMeta get meta => ResourceMeta.of(type);
}

// ─── Resource Meta ────────────────────────────────────────────────────────────
class ResourceMeta {
  final IconData icon;
  final Color    color;
  final Color    bgColor;
  final Color    badgeBg;
  final String   label;

  const ResourceMeta._({
    required this.icon, required this.color,
    required this.bgColor, required this.badgeBg, required this.label,
  });

  static ResourceMeta of(String type) {
    switch (type) {
      case 'youtube': return const ResourceMeta._(icon: Icons.play_circle_rounded,   color: Color(0xFFE53935), bgColor: Color(0xFFFFEBEE), badgeBg: Color(0xFFFFCDD2), label: 'YouTube');
      case 'article': return const ResourceMeta._(icon: Icons.article_rounded,       color: Color(0xFF1565C0), bgColor: Color(0xFFE3F2FD), badgeBg: Color(0xFFBBDEFB), label: 'บทความ');
      case 'website': return const ResourceMeta._(icon: Icons.language_rounded,      color: Color(0xFF00838F), bgColor: Color(0xFFE0F7FA), badgeBg: Color(0xFFB2EBF2), label: 'เว็บไซต์');
      default:        return const ResourceMeta._(icon: Icons.link_rounded,          color: Color(0xFF6A1B9A), bgColor: Color(0xFFF3E5F5), badgeBg: Color(0xFFE1BEE7), label: 'อื่นๆ');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class LearningResourcesScreen extends StatefulWidget {
  const LearningResourcesScreen({super.key});
  @override
  State<LearningResourcesScreen> createState() => _LearningResourcesScreenState();
}

class _LearningResourcesScreenState extends State<LearningResourcesScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  static const _filters    = ['ทั้งหมด', 'YouTube', 'บทความ', 'เว็บไซต์', 'อื่นๆ'];
  static const _filterKeys = ['all', 'youtube', 'article', 'website', 'other'];
  late TabController _tabCtrl;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: _filters.length, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true, floating: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F1729),
            elevation: 0, scrolledUnderElevation: 1,
            shadowColor: const Color(0xFFEAECF2),
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
            title: const Text('แหล่งเรียนรู้', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEAECF2)))),
                child: TabBar(
                  controller: _tabCtrl, isScrollable: true, tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  indicatorColor: const Color(0xFF1A56DB), indicatorWeight: 2.5, indicatorSize: TabBarIndicatorSize.label,
                  labelColor: const Color(0xFF1A56DB), unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: _filters.map((f) => Tab(text: f, height: 44)).toList(),
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase.from('learning_resources').stream(primaryKey: ['id']).order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _errorState();
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB), strokeWidth: 2));
            final all = snapshot.data!.map(LearningResource.fromMap).toList();
            return TabBarView(
              controller: _tabCtrl,
              children: _filterKeys.map((key) {
                final items = key == 'all' ? all : all.where((r) => r.type == key).toList();
                return items.isEmpty ? _emptyState() : _ResourceList(items: items);
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _errorState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFADB5C7)),
    const SizedBox(height: 12),
    const Text('โหลดข้อมูลไม่สำเร็จ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
  ]));

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72,
        decoration: BoxDecoration(color: const Color(0xFFF2F4F8), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFFADB5C7))),
    const SizedBox(height: 14),
    const Text('ยังไม่มีแหล่งเรียนรู้', style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    const Text('ผู้ดูแลระบบยังไม่ได้เพิ่มเนื้อหา', style: TextStyle(color: Color(0xFFADB5C7), fontSize: 12)),
  ]));
}

// ─── Resource List ────────────────────────────────────────────────────────────
class _ResourceList extends StatelessWidget {
  final List<LearningResource> items;
  const _ResourceList({required this.items});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ResourceCard(resource: items[i]),
      ),
    );
  }
}

// ─── Resource Card ────────────────────────────────────────────────────────────
class _ResourceCard extends StatelessWidget {
  final LearningResource resource;
  const _ResourceCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    final meta     = resource.meta;
    final hasImages = resource.hasImages;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResourceDetailScreen(resource: resource))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAECF2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top: รูปแรก หรือ banner ────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: hasImages
                ? Stack(children: [
                    Image.network(resource.imageUrls.first, height: 160, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _bannerFallback(meta)),
                    Container(height: 160, decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.35)]))),
                    Positioned(right: 12, top: 12, child: _badge(meta)),
                    // แสดงจำนวนรูป ถ้ามีมากกว่า 1
                    if (resource.imageUrls.length > 1)
                      Positioned(left: 12, bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.photo_library_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${resource.imageUrls.length} รูป', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                  ])
                : _bannerFallback(meta),
          ),

          // ── Content ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!hasImages) ...[_badge(meta), const SizedBox(height: 8)],
              Text(resource.title,
                  style: const TextStyle(color: Color(0xFF0F1729), fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (resource.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(resource.description,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(resource.url, style: const TextStyle(color: Color(0xFFADB5C7), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFEEF3FF), borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('ดูเพิ่มเติม', style: TextStyle(color: Color(0xFF1A56DB), fontSize: 11, fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF1A56DB)),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bannerFallback(ResourceMeta meta) => Container(
    height: 80, color: meta.bgColor,
    child: Stack(children: [
      Positioned(right: -16, top: -16, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: meta.color.withOpacity(0.08)))),
      Padding(padding: const EdgeInsets.all(16), child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: meta.color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Icon(meta.icon, color: meta.color, size: 24),
      )),
    ]),
  );

  Widget _badge(ResourceMeta meta) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: meta.badgeBg, borderRadius: BorderRadius.circular(20)),
    child: Text(meta.label, style: TextStyle(color: meta.color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ResourceDetailScreen extends StatefulWidget {
  final LearningResource resource;
  const ResourceDetailScreen({super.key, required this.resource});
  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen> {
  int _currentPage = 0;
  final _pageCtrl  = PageController();

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  Future<void> _openUrl() async {
    final uri = Uri.tryParse(widget.resource.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ไม่สามารถเปิดลิงก์ได้")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource  = widget.resource;
    final meta      = resource.meta;
    final hasImages = resource.hasImages;
    final imgCount  = resource.imageUrls.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: CustomScrollView(
        slivers: [
          // ── Hero / Image Gallery App Bar ──────────────────────────────
          SliverAppBar(
            expandedHeight: hasImages ? 300 : 220,
            pinned: true,
            backgroundColor: meta.color,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: hasImages
                  // ── มีรูป: แสดง PageView ─────────────────────────────
                  ? Stack(children: [
                      // PageView รูปภาพ
                      PageView.builder(
                        controller: _pageCtrl,
                        itemCount: imgCount,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (_, i) => Image.network(
                          resource.imageUrls[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _gradientBg(meta),
                        ),
                      ),
                      // gradient ด้านล่าง
                      Positioned.fill(child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            stops: const [0.35, 1.0],
                            colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.72)],
                          ),
                        ),
                      )),
                      // ── Dot indicator ────────────────────────────────
                      if (imgCount > 1)
                        Positioned(
                          right: 16, bottom: 72,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.photo_library_rounded, size: 13, color: Colors.white),
                              const SizedBox(width: 5),
                              Text('${_currentPage + 1} / $imgCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      // ── dots ─────────────────────────────────────────
                      if (imgCount > 1)
                        Positioned(
                          bottom: 56,
                          left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(imgCount, (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentPage == i ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentPage == i ? Colors.white : Colors.white.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                          ),
                        ),
                      // ── ชื่อเรื่อง ────────────────────────────────────
                      Positioned(left: 24, right: 24, bottom: 24,
                        child: _heroContent(meta, resource)),
                    ])
                  // ── ไม่มีรูป: gradient สี ────────────────────────────
                  : _gradientBg(meta, withContent: true, resource: resource),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── รายละเอียดยาว ────────────────────────────────────
                if (resource.detail.isNotEmpty) ...[
                  _sectionCard(icon: Icons.menu_book_rounded, label: 'รายละเอียด',
                      child: Text(resource.detail, style: const TextStyle(color: Color(0xFF0F1729), fontSize: 14, height: 1.7))),
                  const SizedBox(height: 14),
                ],

                // ── คำอธิบายสั้น (fallback ถ้าไม่มี detail) ──────────
                if (resource.description.isNotEmpty && resource.detail.isEmpty) ...[
                  _sectionCard(icon: Icons.info_outline_rounded, label: 'เกี่ยวกับ',
                      child: Text(resource.description, style: const TextStyle(color: Color(0xFF0F1729), fontSize: 14, height: 1.6))),
                  const SizedBox(height: 14),
                ],

                // ── Thumbnail strip (ดูรูปทั้งหมด) ─────────────────
                if (imgCount > 1) ...[
                  _sectionCard(
                    icon: Icons.photo_library_rounded,
                    label: 'รูปภาพทั้งหมด ($imgCount รูป)',
                    child: SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: imgCount,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () {
                            _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                            // scroll ขึ้นไปที่รูป
                            Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 300));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _currentPage == i ? meta.color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(resource.imageUrls[i], fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF2F4F8),
                                      child: const Icon(Icons.broken_image_rounded, color: Color(0xFFADB5C7)))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── ลิงก์ ─────────────────────────────────────────────
                _sectionCard(icon: Icons.link_rounded, label: 'ลิงก์',
                    child: Text(resource.url, style: TextStyle(color: meta.color, fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 28),

                // ── ปุ่มเปิด ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: meta.color, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    icon: Icon(_openIcon(resource.type), size: 20),
                    label: Text(_openLabel(resource.type), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFEAECF2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('กลับ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBg(ResourceMeta meta, {bool withContent = false, LearningResource? resource}) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [meta.color, meta.color.withOpacity(0.75)])),
      child: Stack(children: [
        Positioned(right: -40, top: -40, child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)))),
        Positioned(left: -20, bottom: -30, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
        if (withContent && resource != null)
          Positioned(left: 24, right: 24, bottom: 24, child: _heroContent(meta, resource)),
      ]),
    );
  }

  Widget _heroContent(ResourceMeta meta, LearningResource resource) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Icon(meta.icon, color: Colors.white, size: 28)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Text(meta.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 14),
      Text(resource.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.4), maxLines: 3, overflow: TextOverflow.ellipsis),
    ]);
  }

  Widget _sectionCard({required IconData icon, required String label, required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAECF2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: const Color(0xFF64748B)), const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  IconData _openIcon(String type) { switch (type) { case 'youtube': return Icons.play_arrow_rounded; case 'article': return Icons.chrome_reader_mode_rounded; default: return Icons.open_in_new_rounded; } }
  String _openLabel(String type)  { switch (type) { case 'youtube': return 'เปิดใน YouTube'; case 'article': return 'อ่านบทความ'; case 'website': return 'เปิดเว็บไซต์'; default: return 'เปิดลิงก์'; } }
}