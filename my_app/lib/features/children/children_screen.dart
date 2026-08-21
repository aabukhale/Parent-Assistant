import 'package:flutter/material.dart';
import '../../models/child.dart';
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
    ),
    Child(
      id: '2',
      name: 'محمد',
      age: 10,
      schoolGrade: 'الصف الخامس',
    ),
  ];

  void addChild(Child child) {
    setState(() {
      children.add(child);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'أطفالي',
          style: TextStyle(
            color: Color(0xFF2E3B63),
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 18),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF2E3B63),
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
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

              _buildSummaryCard(),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'أطفالي',
                    style: TextStyle(
                      color: Color(0xFF2E3B63),
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${children.length} أطفال',
                    style: const TextStyle(
                      color: Color(0xFF8A94AA),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              ...children.map(
                (child) => _buildChildCard(child),
              ),

              const SizedBox(height: 10),

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

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E3B63),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF62D9D4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              color: Color(0xFF2E3B63),
              size: 32,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'عائلتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'لديك ${children.length} أطفال في التطبيق',
                  style: const TextStyle(
                    color: Color(0xFFD8DDEC),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF624E),
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Child child) {
    return GestureDetector(
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
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF62D9D4)
                                  .withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.face_rounded,
                              color: Color(0xFF62D9D4),
                              size: 20,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            child.name,
                            style: const TextStyle(
                              color: Color(0xFF2E3B63),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '${child.age} سنوات • ${child.schoolGrade}',
                        style: const TextStyle(
                          color: Color(0xFF8A94AA),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 17,
                  color: Color(0xFF8A94AA),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}