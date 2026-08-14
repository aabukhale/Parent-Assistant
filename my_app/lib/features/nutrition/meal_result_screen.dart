import 'package:flutter/material.dart';

class MealResultScreen extends StatelessWidget {
  const MealResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('تحليل الوجبة'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4DF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: Color(0xFFFF624E),
                  size: 100,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                '🥗 وجبة متوازنة نسبيًا',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              _NutritionItem(
                title: 'البروتين',
                value: 'جيد',
                icon: Icons.fitness_center_rounded,
              ),

              _NutritionItem(
                title: 'الخضار',
                value: 'يحتاج إلى المزيد',
                icon: Icons.eco_rounded,
              ),

              _NutritionItem(
                title: 'الفواكه',
                value: 'جيد',
                icon: Icons.apple_rounded,
              ),

              _NutritionItem(
                title: 'الماء',
                value: 'تذكير بشرب الماء',
                icon: Icons.water_drop_rounded,
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3B63),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  '💡 ملاحظة: هذه اقتراحات عامة وليست تشخيصًا طبيًا. يمكن إضافة المزيد من الخضار أو الفواكه للحصول على وجبة أكثر تنوعًا.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.6,
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

class _NutritionItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _NutritionItem({
    required this.title,
    required this.value,
    required this.icon,
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
          Icon(
            icon,
            color: const Color(0xFF62D9D4),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF2E3B63),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF8A94AA),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}