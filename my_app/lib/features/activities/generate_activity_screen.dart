import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';

class GenerateActivityScreen extends StatefulWidget {
  const GenerateActivityScreen({super.key});

  @override
  State<GenerateActivityScreen> createState() =>
      _GenerateActivityScreenState();
}

class _GenerateActivityScreenState
    extends State<GenerateActivityScreen> {
  String age = '8 سنوات';
  String time = '30 دقيقة';
  String interest = 'الرسم';

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
            'إنشاء نشاط',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أخبرني عن طفلك 🤖',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'وسأقترح نشاطًا مناسبًا له',
                style: TextStyle(
                  color: Color(0xFF8A94AA),
                ),
              ),

              const SizedBox(height: 30),

              _Dropdown(
                title: 'عمر الطفل',
                value: age,
                options: const [
                  '4 سنوات',
                  '5 سنوات',
                  '6 سنوات',
                  '7 سنوات',
                  '8 سنوات',
                  '9 سنوات',
                  '10 سنوات',
                  '11 سنة',
                  '12 سنة',
                ],
                onChanged: (value) {
                  setState(() => age = value!);
                },
              ),

              _Dropdown(
                title: 'الوقت المتوفر',
                value: time,
                options: const [
                  '15 دقيقة',
                  '30 دقيقة',
                  '45 دقيقة',
                  '60 دقيقة',
                ],
                onChanged: (value) {
                  setState(() => time = value!);
                },
              ),

              _Dropdown(
                title: 'الاهتمام',
                value: interest,
                options: const [
                  'الرسم',
                  'القراءة',
                  'الرياضة',
                  'العلوم',
                  'الألعاب',
                  'الموسيقى',
                ],
                onChanged: (value) {
                  setState(() => interest = value!);
                },
              ),

              const SizedBox(height: 25),

              PrimaryButton(
                text: 'إنشاء النشاط ✨',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('النشاط المقترح 🎨'),
                      content: const Text(
                        'اصنع قصة مصورة! نشاط ممتع يساعد الطفل على تنمية الإبداع واللغة.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('رائع'),
                        ),
                      ],
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

class _Dropdown extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2E3B63),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 5,
              ),
              border: InputBorder.none,
            ),
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}