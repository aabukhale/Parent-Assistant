import 'package:flutter/material.dart';
import '../../models/child.dart';
import '../../widgets/stat_card.dart';
import '../screen_time/screen_time_screen.dart';
import '../content_control/content_control_screen.dart';
import '../development/development_screen.dart';
import '../sleep/sleep_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../rewards/rewards_screen.dart';
import '../ai_parenting/ai_parenting_screen.dart';
import '../library/library_screen.dart';

class ChildDetailsScreen extends StatelessWidget {
  final Child child;

  const ChildDetailsScreen({
    super.key,
    required this.child,
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
          title: Text(
            child.name,
            style: const TextStyle(
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
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE4DF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.face_rounded,
                        size: 55,
                        color: Color(0xFFFF624E),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Text(
                      child.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '${child.age} سنوات • ${child.schoolGrade}',
                      style: const TextStyle(
                        color: Color(0xFFD8DDEC),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'وقت الشاشة',
                      value: '2س 15د',
                      subtitle: 'اليوم',
                      icon: Icons.smartphone_rounded,
                      iconColor: const Color(0xFFFF624E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'التعلم',
                      value: '1س 20د',
                      subtitle: 'اليوم',
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFF62D9D4),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'النوم',
                      value: '8س 10د',
                      subtitle: 'أمس',
                      icon: Icons.bedtime_rounded,
                      iconColor: const Color(0xFF7C89B8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'النقاط',
                      value: '250',
                      subtitle: 'نقطة',
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFFFFB84D),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              _FeatureTile(
                icon: Icons.smartphone_rounded,
                title: 'إدارة وقت الشاشة',
                subtitle: 'حدد وقت الاستخدام اليومي',
                color: const Color(0xFFFF624E),
                onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                    builder: (_) => const ScreenTimeScreen(),
                    ),
                );
                },
              ),

              _FeatureTile(
                icon: Icons.lock_outline_rounded,
                title: 'التحكم بالمحتوى',
                subtitle: 'تحكم بالمحتوى المناسب لطفلك',
                color: const Color(0xFF62D9D4),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ContentControlScreen(),
                    ),
                    );
                },
                ),

              _FeatureTile(
                icon: Icons.bar_chart_rounded,
                title: 'تطور الطفل',
                subtitle: 'شاهد تقدم طفلك',
                color: const Color(0xFF7C89B8),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DevelopmentScreen(),
                    ),
                    );
                },
                ),

              _FeatureTile(
                icon: Icons.bedtime_rounded,
                title: 'النوم',
                subtitle: 'تابع عادات النوم',
                color: const Color(0xFF9B8CC2),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SleepScreen(),
                    ),
                    );
                },
                ),
             _FeatureTile(
                icon: Icons.restaurant_rounded,
                title: 'التغذية',
                subtitle: 'تابع وجبات طفلك',
                color: const Color(0xFF62D9D4),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NutritionScreen(),
                    ),
                    );
                },
                ),
              _FeatureTile(
                icon: Icons.stars_rounded,
                title: 'المكافآت',
                subtitle: 'مهام ونقاط ومكافآت',
                color: const Color(0xFFFFB84D),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RewardsScreen(),
                    ),
                    );
                },
                ),

              _FeatureTile(
                icon: Icons.auto_awesome_rounded,
                title: 'مساعد التربية AI',
                subtitle: 'اسألي الذكاء الاصطناعي',
                color: const Color(0xFFFF624E),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AiParentingScreen(),
                    ),
                    );
                },
                ),

              _FeatureTile(
                icon: Icons.menu_book_rounded,
                title: 'مكتبة الأهل',
                subtitle: 'نصائح ومقالات تربوية',
                color: const Color(0xFF62D9D4),
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LibraryScreen(),
                    ),
                    );
                },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
              ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A94AA),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 17,
              color: Color(0xFF9AA3B5),
            ),
          ],
        ),
      ),
    );
  }
}