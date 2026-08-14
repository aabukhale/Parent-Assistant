import 'package:flutter/material.dart';
import '../../widgets/primary_button.dart';

class ExtraTimeScreen extends StatefulWidget {
  const ExtraTimeScreen({super.key});

  @override
  State<ExtraTimeScreen> createState() => _ExtraTimeScreenState();
}

class _ExtraTimeScreenState extends State<ExtraTimeScreen> {
  int selectedMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final options = [15, 30, 45, 60];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'وقت إضافي',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4DF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_rounded,
                  size: 55,
                  color: Color(0xFFFF624E),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'كم تريد أن تمنح طفلك؟',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: options.map((minutes) {
                  final selected = selectedMinutes == minutes;

                  return ChoiceChip(
                    label: Text('$minutes دقيقة'),
                    selected: selected,
                    selectedColor: const Color(0xFF62D9D4),
                    onSelected: (_) {
                      setState(() {
                        selectedMinutes = minutes;
                      });
                    },
                  );
                }).toList(),
              ),

              const Spacer(),

              PrimaryButton(
                text: 'منح $selectedMinutes دقيقة',
                icon: Icons.check_rounded,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}