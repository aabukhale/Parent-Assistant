import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';
import 'extra_time_screen.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  double dailyLimit = 3;
  bool autoPause = true;
  bool notifications = true;

  final List<Map<String, dynamic>> apps = [
    {
      'name': 'YouTube',
      'icon': Icons.play_circle_fill_rounded,
      'time': '55 دقيقة',
      'allowed': true,
    },
    {
      'name': 'الألعاب',
      'icon': Icons.sports_esports_rounded,
      'time': '45 دقيقة',
      'allowed': true,
    },
    {
      'name': 'TikTok',
      'icon': Icons.music_video_rounded,
      'time': '0 دقيقة',
      'allowed': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final used = 2.25;
    final percentage = (used / dailyLimit).clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'وقت الشاشة',
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
              _ScreenTimeSummary(
                used: '2س 15د',
                limit: '${dailyLimit.toInt()} ساعات',
                percentage: percentage,
              ),

              const SizedBox(height: 25),

              const Text(
                'الحد اليومي',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '${dailyLimit.toInt()} ساعات يوميًا',
                style: const TextStyle(
                  color: Color(0xFF8A94AA),
                ),
              ),

              Slider(
                value: dailyLimit,
                min: 1,
                max: 8,
                divisions: 7,
                activeColor: const Color(0xFFFF624E),
                onChanged: (value) {
                  setState(() {
                    dailyLimit = value;
                  });
                },
              ),

              const SizedBox(height: 15),

              _SettingCard(
                icon: Icons.pause_circle_outline_rounded,
                title: 'إيقاف تلقائي',
                subtitle: 'إيقاف الاستخدام عند انتهاء الوقت',
                value: autoPause,
                onChanged: (value) {
                  setState(() {
                    autoPause = value;
                  });
                },
              ),

              _SettingCard(
                icon: Icons.notifications_none_rounded,
                title: 'تنبيهات وقت الشاشة',
                subtitle: 'تنبيه قبل انتهاء الوقت',
                value: notifications,
                onChanged: (value) {
                  setState(() {
                    notifications = value;
                  });
                },
              ),

              const SizedBox(height: 25),

              const Text(
                'التطبيقات والمحتوى',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              ...apps.map(
                (app) => _AppTimeCard(
                  name: app['name'],
                  icon: app['icon'],
                  time: app['time'],
                  allowed: app['allowed'],
                ),
              ),

              const SizedBox(height: 20),

              PrimaryButton(
                text: 'منح وقت إضافي',
                icon: Icons.add_alarm_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExtraTimeScreen(),
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

class _ScreenTimeSummary extends StatelessWidget {
  final String used;
  final String limit;
  final double percentage;

  const _ScreenTimeSummary({
    required this.used,
    required this.limit,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3B63),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.smartphone_rounded,
            color: Color(0xFF62D9D4),
            size: 45,
          ),
          const SizedBox(height: 15),
          Text(
            used,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 35,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'من $limit',
            style: const TextStyle(
              color: Color(0xFFD8DDEC),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFF62D9D4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingCard({
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
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const SizedBox(width: 5),
          Icon(
            icon,
            color: const Color(0xFFFF624E),
            size: 28,
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

class _AppTimeCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final String time;
  final bool allowed;

  const _AppTimeCard({
    required this.name,
    required this.icon,
    required this.time,
    required this.allowed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 35,
            color: allowed
                ? const Color(0xFFFF624E)
                : const Color(0xFF9AA3B5),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF2E3B63),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF8A94AA),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            allowed
                ? Icons.check_circle_rounded
                : Icons.block_rounded,
            color: allowed
                ? const Color(0xFF62D9D4)
                : const Color(0xFFFF624E),
          ),
        ],
      ),
    );
  }
}