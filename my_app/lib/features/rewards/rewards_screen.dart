import 'package:flutter/material.dart';
import 'add_task_screen.dart';
import 'rewards_store_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int points = 240;

  final List<Map<String, dynamic>> tasks = [
    {
      'title': 'ترتيب الغرفة',
      'points': 20,
      'done': true,
      'icon': Icons.cleaning_services_rounded,
    },
    {
      'title': 'قراءة كتاب',
      'points': 30,
      'done': false,
      'icon': Icons.menu_book_rounded,
    },
    {
      'title': 'إنهاء الواجب',
      'points': 40,
      'done': false,
      'icon': Icons.school_rounded,
    },
    {
      'title': 'مساعدة في المنزل',
      'points': 25,
      'done': false,
      'icon': Icons.home_rounded,
    },
  ];

  void completeTask(int index) {
    if (tasks[index]['done']) return;

    setState(() {
      tasks[index]['done'] = true;
      points += tasks[index]['points'] as int;
    });
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
          title: const Text(
            'المكافآت',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFFFF624E),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RewardsStoreScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF624E),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.white,
                      size: 55,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'رصيد النقاط',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'نقطة ⭐',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Row(
                children: [
                  Expanded(
                    child: _SmallStat(
                      title: 'المهام المكتملة',
                      value: '${tasks.where((task) => task['done']).length}',
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallStat(
                      title: 'هذا الأسبوع',
                      value: '+85',
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'مهام اليوم',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ...List.generate(
                tasks.length,
                (index) => _TaskCard(
                  task: tasks[index],
                  onTap: () => completeTask(index),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final task = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddTaskScreen(),
                      ),
                    );

                    if (task != null) {
                      setState(() {
                        tasks.add(task);
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة مهمة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3B63),
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

class _SmallStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SmallStat({
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
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2E3B63),
              fontSize: 22,
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

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool done = task['done'] as bool;

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
            task['icon'] as IconData,
            color: done
                ? const Color(0xFF62D9D4)
                : const Color(0xFFFF624E),
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] as String,
                  style: TextStyle(
                    color: const Color(0xFF2E3B63),
                    fontWeight: FontWeight.bold,
                    decoration:
                        done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '+${task['points']} نقطة',
                  style: const TextStyle(
                    color: Color(0xFF8A94AA),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: done
                  ? const Color(0xFF62D9D4)
                  : const Color(0xFF8A94AA),
            ),
          ),
        ],
      ),
    );
  }
}