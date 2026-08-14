import 'package:flutter/material.dart';
import 'article_details_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final articles = [
      {
        'title': 'كيف أتعامل مع عصبية طفلي؟',
        'category': 'السلوك',
        'icon': Icons.psychology_rounded,
      },
      {
        'title': 'تنظيم وقت الشاشة',
        'category': 'وقت الشاشة',
        'icon': Icons.phone_android_rounded,
      },
      {
        'title': 'كيف أشجع طفلي على القراءة؟',
        'category': 'التعلم',
        'icon': Icons.menu_book_rounded,
      },
      {
        'title': 'بناء شخصية الطفل',
        'category': 'التربية',
        'icon': Icons.emoji_people_rounded,
      },
      {
        'title': 'التعامل مع الغيرة بين الأطفال',
        'category': 'العلاقات',
        'icon': Icons.favorite_rounded,
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'مكتبة الأهل',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final article = articles[index];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailsScreen(
                      title: article['title'] as String,
                      category: article['category'] as String,
                    ),
                  ),
                );
              },
              child: Container(
                margin:
                    const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFE8FAF9),
                        borderRadius:
                            BorderRadius.circular(17),
                      ),
                      child: Icon(
                        article['icon'] as IconData,
                        color:
                            const Color(0xFF62D9D4),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            article['category']
                                as String,
                            style: const TextStyle(
                              color:
                                  Color(0xFFFF624E),
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            article['title'] as String,
                            style: const TextStyle(
                              color:
                                  Color(0xFF2E3B63),
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'قراءة • 5 دقائق',
                            style: TextStyle(
                              color:
                                  Color(0xFF8A94AA),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 16,
                      color: Color(0xFF8A94AA),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}