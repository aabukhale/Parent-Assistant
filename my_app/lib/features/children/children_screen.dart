import 'package:flutter/material.dart';
import '../../models/child.dart';
import '../../widgets/child_card.dart';
import '../../widgets/primary_button.dart';
import 'add_child_screen.dart';
import 'child_details_screen.dart';

class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key});

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  final List<Child> children = [
    Child(
      id: '1',
      name: 'ليان',
      age: 8,
      schoolGrade: 'الصف الثالث',
      interests: ['الرسم', 'القراءة'],
      learningGoals: ['تحسين القراءة', 'الرياضيات'],
    ),
    Child(
      id: '2',
      name: 'محمد',
      age: 10,
      schoolGrade: 'الصف الخامس',
      interests: ['الرياضة', 'العلوم'],
      learningGoals: ['العلوم', 'اللغة الإنجليزية'],
    ),
  ];

  void addChild(Child child) {
    setState(() {
      children.add(child);
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
            'أطفالي',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تابع واهتم بتطور أطفالك ❤️',
                style: TextStyle(
                  color: Color(0xFF8A94AA),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 25),

              ...children.map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ChildCard(
                    child: child,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChildDetailsScreen(
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 15),

              PrimaryButton(
                text: 'إضافة طفل',
                icon: Icons.add_rounded,
                onPressed: () async {
                  final child = await Navigator.push<Child>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddChildScreen(),
                    ),
                  );

                  if (child != null) {
                    addChild(child);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}