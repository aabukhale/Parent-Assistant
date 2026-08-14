import 'package:flutter/material.dart';
import '../../models/child.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final gradeController = TextEditingController();

  final List<String> interests = [
    'الرسم',
    'القراءة',
    'الرياضة',
    'الألعاب',
    'العلوم',
    'الموسيقى',
  ];

  final List<String> selectedInterests = [];

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    gradeController.dispose();
    super.dispose();
  }
  String _convertArabicDigits(String input) {
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = input;
  for (int i = 0; i < arabic.length; i++) {
    result = result.replaceAll(arabic[i], i.toString());
  }
  return result;
  }

  void saveChild() {
    if (nameController.text.trim().isEmpty ||
        ageController.text.trim().isEmpty ||
        gradeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تعبئة جميع المعلومات الأساسية'),
        ),
      );
      return;
    }

    final child = Child(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      age: int.tryParse(_convertArabicDigits(ageController.text.trim())) ?? 0,
      schoolGrade: gradeController.text.trim(),
      interests: selectedInterests,
      learningGoals: [],
    );

    Navigator.pop(context, child);
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
            'إضافة طفل',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4DF),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  size: 55,
                  color: Color(0xFFFF624E),
                ),
              ),

              const SizedBox(height: 25),

              AppTextField(
                label: 'اسم الطفل',
                hint: 'مثال: ليان',
                controller: nameController,
              ),

              const SizedBox(height: 18),

              AppTextField(
                label: 'العمر',
                hint: 'مثال: 8',
                controller: ageController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 18),

              AppTextField(
                label: 'المرحلة الدراسية',
                hint: 'مثال: الصف الثالث',
                controller: gradeController,
              ),

              const SizedBox(height: 25),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الاهتمامات',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests.map((interest) {
                  final selected =
                      selectedInterests.contains(interest);

                  return FilterChip(
                    label: Text(interest),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          selectedInterests.add(interest);
                        } else {
                          selectedInterests.remove(interest);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF62D9D4),
                    backgroundColor: Colors.white,
                  );
                }).toList(),
              ),

              const SizedBox(height: 35),

              PrimaryButton(
                text: 'حفظ الطفل',
                icon: Icons.check_rounded,
                onPressed: saveChild,
              ),
            ],
          ),
        ),
      ),
    );
  }
}