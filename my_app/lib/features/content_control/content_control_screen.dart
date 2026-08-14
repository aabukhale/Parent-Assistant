import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';

class ContentControlScreen extends StatefulWidget {
  const ContentControlScreen({super.key});

  @override
  State<ContentControlScreen> createState() =>
      _ContentControlScreenState();
}

class _ContentControlScreenState
    extends State<ContentControlScreen> {

  bool educational = true;
  bool entertainment = true;
  bool games = true;
  bool socialMedia = false;
  bool ageFilter = true;

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
            'التحكم بالمحتوى',
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
              const SizedBox(height: 20),

              const Text(
                'تحكم بالمحتوى الذي يشاهده طفلك',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              _ContentItem(
                icon: Icons.school_rounded,
                title: 'المحتوى التعليمي',
                subtitle: 'السماح بالمحتوى التعليمي',
                value: educational,
                onChanged: (value) {
                  setState(() {
                    educational = value;
                  });
                },
              ),

              _ContentItem(
                icon: Icons.movie_rounded,
                title: 'المحتوى الترفيهي',
                subtitle: 'السماح بالمحتوى الترفيهي',
                value: entertainment,
                onChanged: (value) {
                  setState(() {
                    entertainment = value;
                  });
                },
              ),

              _ContentItem(
                icon: Icons.games_rounded,
                title: 'الألعاب',
                subtitle: 'السماح بالألعاب',
                value: games,
                onChanged: (value) {
                  setState(() {
                    games = value;
                  });
                },
              ),

              _ContentItem(
                icon: Icons.groups_rounded,
                title: 'مواقع التواصل',
                subtitle: 'السماح بمواقع التواصل',
                value: socialMedia,
                onChanged: (value) {
                  setState(() {
                    socialMedia = value;
                  });
                },
              ),

              _ContentItem(
                icon: Icons.shield_rounded,
                title: 'فلتر العمر',
                subtitle: 'منع المحتوى غير المناسب للعمر',
                value: ageFilter,
                onChanged: (value) {
                  setState(() {
                    ageFilter = value;
                  });
                },
              ),

              const SizedBox(height: 25),

              PrimaryButton(
                text: 'حفظ الإعدادات',
                icon: Icons.check_rounded,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ إعدادات المحتوى'),
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

class _ContentItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ContentItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
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
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFFF624E),
            size: 30,
          ),

          const SizedBox(width: 15),

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

          Switch(
            value: value,
            activeColor: const Color(0xFFFF624E),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}