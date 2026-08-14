import 'package:flutter/material.dart';

class RewardsStoreScreen extends StatelessWidget {
  const RewardsStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rewards = [
      {
        'title': '30 دقيقة وقت شاشة',
        'points': 100,
        'icon': Icons.phone_android_rounded,
      },
      {
        'title': 'اختيار فيلم الليلة',
        'points': 150,
        'icon': Icons.movie_rounded,
      },
      {
        'title': 'اختيار وجبة مفضلة',
        'points': 200,
        'icon': Icons.restaurant_rounded,
      },
      {
        'title': 'نشاط خاص مع العائلة',
        'points': 300,
        'icon': Icons.family_restroom_rounded,
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('متجر المكافآت'),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final reward = rewards[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Icon(
                    reward['icon'] as IconData,
                    color: const Color(0xFFFFB84D),
                    size: 35,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward['title'] as String,
                          style: const TextStyle(
                            color: Color(0xFF2E3B63),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${reward['points']} نقطة',
                          style: const TextStyle(
                            color: Color(0xFF8A94AA),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا توجد نقاط كافية حاليًا'),
                        ),
                      );
                    },
                    child: const Text('استبدال'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}