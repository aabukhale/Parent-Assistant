import 'package:flutter/material.dart';

class GamePlayScreen extends StatefulWidget {
  final String title;
  final Color color;

  const GamePlayScreen({
    super.key,
    required this.title,
    required this.color,
  });

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  int selectedAnswer = -1;
  int score = 0;

  final List<String> answers = [
    '8',
    '12',
    '15',
    '20',
  ];

  void checkAnswer(int index) {
    setState(() {
      selectedAnswer = index;

      if (index == 1) {
        score += 10;
      }
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
          title: Text(widget.title),
        ),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'السؤال 1 من 10',
                    style: TextStyle(
                      color: Color(0xFF8A94AA),
                    ),
                  ),
                  Text(
                    '⭐ $score',
                    style: const TextStyle(
                      color: Color(0xFFFFB84D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 35),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Text(
                  'كم يساوي 4 + 8 ؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              ...List.generate(
                answers.length,
                (index) => GestureDetector(
                  onTap: () => checkAnswer(index),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: selectedAnswer == index
                          ? widget.color.withOpacity(.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selectedAnswer == index
                            ? widget.color
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      answers[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF2E3B63),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              if (selectedAnswer != -1)
                Text(
                  selectedAnswer == 1
                      ? '🎉 إجابة صحيحة!'
                      : 'حاول مرة أخرى',
                  style: TextStyle(
                    color: selectedAnswer == 1
                        ? const Color(0xFF42A59F)
                        : const Color(0xFFFF624E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}