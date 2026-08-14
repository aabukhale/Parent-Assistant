import 'package:flutter/material.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController titleController = TextEditingController();
  int points = 20;

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
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
          title: const Text('إضافة مهمة'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'اسم المهمة',
                  hintText: 'مثال: قراءة كتاب',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFFFB84D),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'النقاط',
                        style: TextStyle(
                          color: Color(0xFF2E3B63),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DropdownButton<int>(
                      value: points,
                      items: [10, 20, 30, 40, 50]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value نقطة'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            points = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    Navigator.pop(
                      context,
                      {
                        'title': titleController.text.trim(),
                        'points': points,
                        'done': false,
                        'icon': Icons.task_alt_rounded,
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
                  child: const Text('حفظ المهمة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}