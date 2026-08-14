import 'package:flutter/material.dart';

class DevelopmentScreen extends StatelessWidget {
  const DevelopmentScreen({super.key});

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
            'تطور الطفل',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProgressHeader(),

              const SizedBox(height: 25),

              const Text(
                'التقدم هذا الأسبوع',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              _ProgressCard(
                title: 'القراءة',
                value: 0.78,
                percentage: '78%',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF62D9D4),
              ),

              _ProgressCard(
                title: 'التعلم',
                value: 0.65,
                percentage: '65%',
                icon: Icons.school_rounded,
                color: const Color(0xFF7C89B8),
              ),

              _ProgressCard(
                title: 'النشاط',
                value: 0.82,
                percentage: '82%',
                icon: Icons.directions_run_rounded,
                color: const Color(0xFFFFB84D),
              ),

              _ProgressCard(
                title: 'العادات',
                value: 0.70,
                percentage: '70%',
                icon: Icons.favorite_rounded,
                color: const Color(0xFFFF624E),
              ),

              const SizedBox(height: 25),

              const Text(
                'ملخص الأسبوع',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'ساعات التعلم',
                      value: '6.5',
                      icon: Icons.school_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'الأنشطة',
                      value: '12',
                      icon: Icons.emoji_events_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'الكتب',
                      value: '4',
                      icon: Icons.menu_book_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'الألعاب',
                      value: '8',
                      icon: Icons.sports_esports_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3B63),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🌟 أحسنت!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'تقدم طفلك هذا الأسبوع أفضل من الأسبوع الماضي بـ 12%. استمروا بهذا التقدم!',
                      style: TextStyle(
                        color: Color(0xFFD8DDEC),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3B63),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.trending_up_rounded,
            color: Color(0xFF62D9D4),
            size: 50,
          ),
          SizedBox(height: 12),
          Text(
            'تطور هذا الأسبوع',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 5),
          Text(
            '+12%',
            style: TextStyle(
              color: Color(0xFF62D9D4),
              fontSize: 38,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'مقارنة بالأسبوع الماضي',
            style: TextStyle(
              color: Color(0xFFD8DDEC),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final double value;
  final String percentage;
  final IconData icon;
  final Color color;

  const _ProgressCard({
    required this.title,
    required this.value,
    required this.percentage,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
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
                percentage,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: const Color(0xFFECEEF4),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF62D9D4),
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2E3B63),
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A94AA),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}