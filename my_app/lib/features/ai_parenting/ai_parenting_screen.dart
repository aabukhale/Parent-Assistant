import 'package:flutter/material.dart';

class AiParentingScreen extends StatefulWidget {
  const AiParentingScreen({super.key});

  @override
  State<AiParentingScreen> createState() =>
      _AiParentingScreenState();
}

class _AiParentingScreenState
    extends State<AiParentingScreen> {
  final TextEditingController controller =
      TextEditingController();

  final List<Map<String, String>> messages = [
    {
      'role': 'ai',
      'text':
          'مرحبًا 👋 أنا مساعد التربية الذكي. كيف يمكنني مساعدتك اليوم؟',
    },
  ];

  final suggestions = [
    'طفلي عصبي كثيرًا',
    'طفلي لا يركز بالدراسة',
    'كيف أنظم وقت الشاشة؟',
    'طفلي لا يريد القراءة',
  ];

  void sendMessage([String? suggestion]) {
    final text = suggestion ?? controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      messages.add({
        'role': 'parent',
        'text': text,
      });

      messages.add({
        'role': 'ai',
        'text':
            'أفهمك ❤️. يمكننا التعامل مع هذه المشكلة بخطوات بسيطة. حاولي أولًا فهم السبب وراء هذا السلوك، ثم ضعي روتينًا واضحًا ومكافآت بسيطة عند الالتزام. إذا أخبرتيني بعمر الطفل ومتى تحدث المشكلة، سأعطيك خطة أكثر مناسبة.',
      });
    });

    controller.clear();
  }

  @override
  void dispose() {
    controller.dispose();
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
          title: const Text(
            'مساعد التربية AI',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.auto_awesome,
                color: Color(0xFFFF624E),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isAi = message['role'] == 'ai';

                  return Align(
                    alignment: isAi
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 320,
                      ),
                      margin:
                          const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isAi
                            ? Colors.white
                            : const Color(0xFF2E3B63),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        message['text']!,
                        style: TextStyle(
                          color: isAi
                              ? const Color(0xFF2E3B63)
                              : Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(
              height: 55,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15),
                children: suggestions
                    .map(
                      (suggestion) => Padding(
                        padding:
                            const EdgeInsets.only(left: 8),
                        child: ActionChip(
                          label: Text(suggestion),
                          onPressed: () =>
                              sendMessage(suggestion),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'اكتب سؤالك هنا...',
                        filled: true,
                        fillColor:
                            const Color(0xFFF7F8FC),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor:
                        const Color(0xFFFF624E),
                    child: IconButton(
                      onPressed: sendMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}