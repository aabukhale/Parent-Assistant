import 'package:flutter/material.dart';
import 'meal_result_screen.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

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
            'التغذية',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3B63),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.restaurant_rounded,
                      color: Color(0xFF62D9D4),
                      size: 50,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'مساعد التغذية الذكي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'حلّل وجبات طفلك واحصل على اقتراحات غذائية عامة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD8DDEC),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MealResultScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        color: Color(0xFFFF624E),
                        size: 55,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'تصوير وجبة',
                        style: TextStyle(
                          color: Color(0xFF2E3B63),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'صوّر وجبة طفلك للحصول على تحليل عام',
                        style: TextStyle(
                          color: Color(0xFF8A94AA),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'اقتراحات اليوم',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const _MealCard(
                icon: Icons.breakfast_dining_rounded,
                title: 'الفطور',
                text: 'بيض + خبز كامل + فواكه',
              ),

              const _MealCard(
                icon: Icons.lunch_dining_rounded,
                title: 'الغداء',
                text: 'أرز + دجاج + خضار',
              ),

              const _MealCard(
                icon: Icons.dinner_dining_rounded,
                title: 'العشاء',
                text: 'ساندويش جبنة + خضار',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _MealCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            color: Color(0xFF62D9D4),
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF2E3B63),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF8A94AA),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}