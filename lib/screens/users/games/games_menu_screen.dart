import 'package:flutter/material.dart';
import 'matching_game_screen.dart';
import 'sentence_completion_screen.dart';
import 'word_search_screen.dart';

class GamesMenuScreen extends StatelessWidget {
  const GamesMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เกมฝึกคำศัพท์'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _gameCard(
              context,
              title: 'จับคู่คำศัพท์',
              icon: Icons.grid_on,
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MatchingGameScreen()),
              ),
            ),
            _gameCard(
              context,
              title: 'เติมคำในประโยค',
              icon: Icons.edit_note,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SentenceCompletionScreen()),
              ),
            ),
            _gameCard(
              context,
              title: 'ค้นหาคำศัพท์',
              icon: Icons.search,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WordSearchScreen()),
              ),
            ),
            _gameCard(
              context,
              title: 'Leaderboard',
              icon: Icons.emoji_events,
              color: Colors.deepPurple,
              onTap: () => Navigator.pushNamed(context, '/games/leaderboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
