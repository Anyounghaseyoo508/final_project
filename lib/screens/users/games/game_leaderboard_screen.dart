import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameLeaderboardScreen extends StatefulWidget {
  const GameLeaderboardScreen({super.key});

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  static const _gameTypes = {
    'matching': 'จับคู่คำศัพท์',
    'sentence_completion': 'เติมคำในประโยค',
    'word_search': 'ค้นหาคำศัพท์',
  };

  late final TabController _tabController;
  bool _isLoading = true;
  String? _error;
  final Map<String, List<Map<String, dynamic>>> _boards = {
    for (final key in _gameTypes.keys) key: <Map<String, dynamic>>[],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _gameTypes.length, vsync: this);
    _loadLeaderboards();
  }

  Future<void> _loadLeaderboards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final usersResponse =
          await _supabase.from('users').select('id, display_name, email');
      final usersById = <String, Map<String, dynamic>>{
        for (final row in usersResponse)
          row['id'] as String: Map<String, dynamic>.from(row as Map),
      };

      for (final gameType in _gameTypes.keys) {
        final response = await _supabase
            .from('game_scores')
            .select('user_id, score, moves, created_at')
            .eq('game_type', gameType)
            .order('score', ascending: false)
            .order('created_at', ascending: true)
            .limit(20);

        final rows = List<Map<String, dynamic>>.from(response).map((row) {
          final userId = row['user_id'] as String?;
          final user = userId == null ? null : usersById[userId];
          return {
            ...row,
            'users': user,
          };
        }).toList();

        _boards[gameType] = rows;
      }
    } catch (e) {
      _error = 'โหลดอันดับไม่สำเร็จ: $e';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _displayName(Map<String, dynamic> row) {
    final user = row['users'] as Map<String, dynamic>?;
    final displayName = user?['display_name'] as String?;
    final email = user?['email'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty)
      return displayName;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Unknown';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard เกม'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _gameTypes.values.map((name) => Tab(text: name)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadLeaderboards,
                  child: TabBarView(
                    controller: _tabController,
                    children: _gameTypes.keys.map((gameType) {
                      final rows = _boards[gameType] ?? [];
                      if (rows.isEmpty) {
                        return ListView(
                          children: [
                            SizedBox(height: 180),
                            Center(child: Text('ยังไม่มีคะแนนในเกมนี้')),
                          ],
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final score = row['score'] ?? 0;
                          final moves = row['moves'];
                          final rank = index + 1;

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: rank == 1
                                    ? Colors.amber
                                    : rank == 2
                                        ? Colors.blueGrey
                                        : rank == 3
                                            ? Colors.brown
                                            : Colors.blue.shade100,
                                child: Text('$rank'),
                              ),
                              title: Text(_displayName(row)),
                              subtitle: moves != null
                                  ? Text('Moves: $moves')
                                  : const SizedBox.shrink(),
                              trailing: Text(
                                '$score คะแนน',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
