import 'package:flutter/material.dart';

class ActivityDetailsScreen extends StatelessWidget {
  final String title;
  final String category;
  final String duration;
  final IconData icon;
  final Color color;

  const ActivityDetailsScreen({
    super.key,
    required this.title,
    required this.category,
    required this.duration,
    required this.icon,
    required this.color,
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
          title: const Text('تفاصيل النشاط'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  icon,
                  size: 90,
                  color: color,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                '$category • $duration',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              _Section(
                title: '🎯 الهدف من النشاط',
                text:
                    'تنمية الإبداع والتفكير والتركيز لدى الطفل بطريقة ممتعة وتفاعلية.',
              ),

              _Section(
                title: '🧰 الأدوات المطلوبة',
                text:
                    'ورق، ألوان، قلم رصاص وبعض الأدوات الموجودة في المنزل.',
              ),

              _Section(
                title: '📝 طريقة التنفيذ',
                text:
                    'ابدأ بشرح النشاط للطفل، ثم اترك له مساحة للتجربة والإبداع، وفي النهاية تحدث معه عما تعلمه.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String text;

  const _Section({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
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
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF737E94),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}