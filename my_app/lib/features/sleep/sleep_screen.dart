import 'package:flutter/material.dart';
import 'add_sleep_screen.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final List<Map<String, String>> sleepRecords = [
    {
      'date': 'الأربعاء',
      'sleep': '9:30 م',
      'wake': '7:15 ص',
      'duration': '9س 45د',
    },
    {
      'date': 'الثلاثاء',
      'sleep': '10:00 م',
      'wake': '7:00 ص',
      'duration': '9س',
    },
    {
      'date': 'الاثنين',
      'sleep': '9:45 م',
      'wake': '6:50 ص',
      'duration': '9س 5د',
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
            'النوم',
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
                      Icons.bedtime_rounded,
                      color: Color(0xFFB8B5E8),
                      size: 50,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'متوسط النوم',
                      style: TextStyle(
                        color: Color(0xFFD8DDEC),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '9س 17د',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'ممتاز لعمر طفلك 🌙',
                      style: TextStyle(
                        color: Color(0xFF62D9D4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Row(
                children: [
                  Expanded(
                    child: _SleepStat(
                      title: 'وقت النوم',
                      value: '9:30 م',
                      icon: Icons.nightlight_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SleepStat(
                      title: 'وقت الاستيقاظ',
                      value: '7:00 ص',
                      icon: Icons.wb_sunny_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'سجل النوم',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ...sleepRecords.map(
                (record) => _SleepRecord(record: record),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddSleepScreen(),
                      ),
                    );

                    if (result != null) {
                      setState(() {
                        sleepRecords.insert(0, result);
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة سجل نوم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF624E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
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

class _SleepStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SleepStat({
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
            color: const Color(0xFF7C89B8),
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2E3B63),
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
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

class _SleepRecord extends StatelessWidget {
  final Map<String, String> record;

  const _SleepRecord({
    required this.record,
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
            Icons.bedtime_rounded,
            color: Color(0xFF7C89B8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              record['date']!,
              style: const TextStyle(
                color: Color(0xFF2E3B63),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record['sleep']} → ${record['wake']}',
                style: const TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 12,
                ),
              ),
              Text(
                record['duration']!,
                style: const TextStyle(
                  color: Color(0xFF62D9D4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}