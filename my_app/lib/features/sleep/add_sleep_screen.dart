import 'package:flutter/material.dart';

class AddSleepScreen extends StatefulWidget {
  const AddSleepScreen({super.key});

  @override
  State<AddSleepScreen> createState() => _AddSleepScreenState();
}

class _AddSleepScreenState extends State<AddSleepScreen> {
  TimeOfDay sleepTime = const TimeOfDay(hour: 21, minute: 30);
  TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);

  Future<void> selectTime(bool sleep) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: sleep ? sleepTime : wakeTime,
    );

    if (selected == null) return;

    setState(() {
      if (sleep) {
        sleepTime = selected;
      } else {
        wakeTime = selected;
      }
    });
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص' : 'م';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('إضافة نوم'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Icon(
                Icons.bedtime_rounded,
                size: 80,
                color: Color(0xFF7C89B8),
              ),

              const SizedBox(height: 30),

              _TimePickerCard(
                title: 'وقت النوم',
                time: formatTime(sleepTime),
                icon: Icons.nightlight_rounded,
                onTap: () => selectTime(true),
              ),

              _TimePickerCard(
                title: 'وقت الاستيقاظ',
                time: formatTime(wakeTime),
                icon: Icons.wb_sunny_rounded,
                onTap: () => selectTime(false),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      {
                        'date': 'اليوم',
                        'sleep': formatTime(sleepTime),
                        'wake': formatTime(wakeTime),
                        'duration': '9س 30د',
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF624E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'حفظ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
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

class _TimePickerCard extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  const _TimePickerCard({
    required this.title,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF7C89B8),
              size: 32,
            ),
            const SizedBox(width: 15),
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
              time,
              style: const TextStyle(
                color: Color(0xFFFF624E),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}