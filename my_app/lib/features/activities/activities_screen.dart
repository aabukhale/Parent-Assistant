import 'package:flutter/material.dart';
import 'activity_details_screen.dart';
import 'generate_activity_screen.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  final List<Map<String, dynamic>> activities = const [
    {
      'title': 'اصنع قصة مصورة',
      'category': 'إبداع',
      'duration': '30 دقيقة',
      'icon': Icons.brush_rounded,
      'color': Color(0xFFFF624E),
    },
    {
      'title': 'تجربة علمية بسيطة',
      'category': 'علوم',
      'duration': '25 دقيقة',
      'icon': Icons.science_rounded,
      'color': Color(0xFF62D9D4),
    },
    {
      'title': 'لعبة البحث عن الكنز',
      'category': 'ذكاء',
      'duration': '40 دقيقة',
      'icon': Icons.search_rounded,
      'color': Color(0xFFFFB84D),
    },
    {
      'title': 'ساعة القراءة',
      'category': 'تعلم',
      'duration': '20 دقيقة',
      'icon': Icons.menu_book_rounded,
      'color': Color(0xFF7C89B8),
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
            'الأنشطة',
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
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const GenerateActivityScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3B63),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF62D9D4),
                        size: 42,
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ولّد نشاطًا بالذكاء الاصطناعي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'حسب عمر طفلك واهتماماته والوقت المتوفر',
                              style: TextStyle(
                                color: Color(0xFFD8DDEC),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'أنشطة مقترحة اليوم',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              ...activities.map(
                (activity) => _ActivityCard(
                  title: activity['title'],
                  category: activity['category'],
                  duration: activity['duration'],
                  icon: activity['icon'],
                  color: activity['color'],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailsScreen(
                          title: activity['title'],
                          category: activity['category'],
                          duration: activity['duration'],
                          icon: activity['icon'],
                          color: activity['color'],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String category;
  final String duration;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.category,
    required this.duration,
    required this.icon,
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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2E3B63),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$category • $duration',
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