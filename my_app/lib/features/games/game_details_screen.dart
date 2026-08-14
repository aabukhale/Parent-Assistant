import 'package:flutter/material.dart';
import 'game_play_screen.dart';

class GameDetailsScreen extends StatelessWidget {
  final String title;
  final String category;
  final IconData icon;
  final Color color;
  final String level;

  const GameDetailsScreen({
    super.key,
    required this.title,
    required this.category,
    required this.icon,
    required this.color,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('اللعبة'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 230,
                decoration: BoxDecoration(
                  color: color.withOpacity(.15),
                  borderRadius: BorderRadius.circular(35),
                ),
                child: Icon(
                  icon,
                  size: 100,
                  color: color,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                '$category • المستوى $level',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'لعبة تعليمية ممتعة تساعد الطفل على التعلم وتطوير مهاراته بطريقة تفاعلية.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF737E94),
                  height: 1.6,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GamePlayScreen(
                          title: title,
                          color: color,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF624E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'ابدأ اللعب 🎮',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}