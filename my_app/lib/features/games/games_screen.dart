import 'package:flutter/material.dart';
import 'game_details_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  final games = const [
    {
      'title': 'تحدي الرياضيات',
      'category': 'رياضيات',
      'icon': Icons.calculate_rounded,
      'color': Color(0xFFFF624E),
      'level': 'مبتدئ',
    },
    {
      'title': 'الكلمات المفقودة',
      'category': 'لغة',
      'icon': Icons.abc_rounded,
      'color': Color(0xFF62D9D4),
      'level': 'متوسط',
    },
    {
      'title': 'اختبار الذكاء',
      'category': 'ذكاء',
      'icon': Icons.psychology_rounded,
      'color': Color(0xFF7C89B8),
      'level': 'متوسط',
    },
    {
      'title': 'استوديو الرسم',
      'category': 'رسم',
      'icon': Icons.palette_rounded,
      'color': Color(0xFFFFB84D),
      'level': 'سهل',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'الألعاب التعليمية',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: games.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .85,
          ),
          itemBuilder: (context, index) {
            final game = games[index];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailsScreen(
                      title: game['title'] as String,
                      category: game['category'] as String,
                      icon: game['icon'] as IconData,
                      color: game['color'] as Color,
                      level: game['level'] as String,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color:
                            (game['color'] as Color).withOpacity(.15),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        game['icon'] as IconData,
                        size: 40,
                        color: game['color'] as Color,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Text(
                      game['title'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF2E3B63),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      '${game['category']} • ${game['level']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8A94AA),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}