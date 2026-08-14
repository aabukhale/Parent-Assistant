import 'package:flutter/material.dart';

class ArticleDetailsScreen extends StatelessWidget {
  final String title;
  final String category;

  const ArticleDetailsScreen({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(category),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3B63),
                  borderRadius:
                      BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF62D9D4),
                  size: 80,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                '5 دقائق قراءة',
                style: TextStyle(
                  color: Color(0xFFFF624E),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'نصيحة اليوم 🌱',
                style: TextStyle(
                  color: Color(0xFF2E3B63),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'كل طفل يتصرف بطريقة مختلفة، ومن المهم أن نحاول فهم السبب وراء السلوك قبل التعامل معه. تحدثي مع طفلك بهدوء، استمعي إليه، وضعي قواعد واضحة وثابتة.',
                style: TextStyle(
                  color: Color(0xFF59657E),
                  fontSize: 16,
                  height: 1.8,
                ),
              ),

              const SizedBox(height: 25),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خطوات عملية',
                      style: TextStyle(
                        color: Color(0xFF2E3B63),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      '1. استمعي للطفل دون مقاطعته.',
                      style: TextStyle(height: 1.8),
                    ),
                    Text(
                      '2. حاولي معرفة سبب المشكلة.',
                      style: TextStyle(height: 1.8),
                    ),
                    Text(
                      '3. ضعي قاعدة واضحة وبسيطة.',
                      style: TextStyle(height: 1.8),
                    ),
                    Text(
                      '4. امدحي السلوك الإيجابي.',
                      style: TextStyle(height: 1.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}