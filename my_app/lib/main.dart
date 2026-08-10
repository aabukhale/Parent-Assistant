import 'package:flutter/material.dart';

import 'models/child.dart';
import 'widgets/app_background.dart';
import 'widgets/app_text_field.dart';
import 'widgets/primary_button.dart';
import 'widgets/secondary_button.dart';
import 'widgets/stat_card.dart';
import 'widgets/child_card.dart';
import 'widgets/bottom_navigation.dart';

void main() {
  runApp(const ParentAssistantApp());
}

class ParentAssistantApp extends StatelessWidget {
  const ParentAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parent Assistant',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E3B63),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: AppBackground(
          darkHeader: true,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 45),

                // Logo
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(55),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 28,
                        bottom: 45,
                        child: Container(
                          width: 65,
                          height: 65,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF624E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sentiment_satisfied_alt_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 28,
                        bottom: 55,
                        child: Container(
                          width: 55,
                          height: 55,
                          decoration: const BoxDecoration(
                            color: Color(0xFF62D9D4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sentiment_satisfied_alt_rounded,
                            color: Color(0xFF2E3B63),
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Parent Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 100),

                // White content section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    28,
                    45,
                    28,
                    35,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(55),
                      topRight: Radius.circular(55),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'أهلًا بكم',
                        style: TextStyle(
                          color: Color(0xFF20283F),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'مساعدك الذكي في رحلة التربية\n'
                        'وتنظيم حياة أطفالك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8A94AA),
                          fontSize: 17,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 40),

                      PrimaryButton(
                        text: 'إنشاء حساب جديد',
                        icon: Icons.person_add_alt_1_rounded,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterDemoScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      SecondaryButton(
                        text: 'لدي حساب بالفعل',
                        icon: Icons.login_rounded,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginDemoScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      const Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Color(0xFFDDE1EA),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 15),
                            child: Text(
                              'أو',
                              style: TextStyle(
                                color: Color(0xFF9AA3B5),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Color(0xFFDDE1EA),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.fingerprint_rounded,
                          size: 30,
                          color: Color(0xFF9AA3B5),
                        ),
                        label: const Text(
                          'دخول سريع لولي الأمر',
                          style: TextStyle(
                            color: Color(0xFF9AA3B5),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginDemoScreen extends StatelessWidget {
  const LoginDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل الدخول'),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),

              const Text(
                'مرحبًا بعودتك 👋',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3B63),
                ),
              ),

              const SizedBox(height: 40),

              const AppTextField(
                label: 'البريد الإلكتروني',
                hint: 'أدخل بريدك الإلكتروني',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 20),

              const AppTextField(
                label: 'كلمة المرور',
                hint: 'أدخل كلمة المرور',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
              ),

              const SizedBox(height: 30),

              PrimaryButton(
                text: 'تسجيل الدخول',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardDemoScreen(),
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

class RegisterDemoScreen extends StatelessWidget {
  const RegisterDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إنشاء حساب'),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Text(
                'لنبدأ رحلتنا 👨‍👩‍👧',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3B63),
                ),
              ),

              const SizedBox(height: 35),

              const AppTextField(
                label: 'الاسم',
                hint: 'أدخل اسمك',
                prefixIcon: Icons.person_outline_rounded,
              ),

              const SizedBox(height: 18),

              const AppTextField(
                label: 'البريد الإلكتروني',
                hint: 'example@email.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 18),

              const AppTextField(
                label: 'كلمة المرور',
                hint: 'أدخل كلمة المرور',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
              ),

              const SizedBox(height: 30),

              PrimaryButton(
                text: 'إنشاء الحساب',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardDemoScreen(),
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

class DashboardDemoScreen extends StatefulWidget {
  const DashboardDemoScreen({super.key});

  @override
  State<DashboardDemoScreen> createState() =>
      _DashboardDemoScreenState();
}

class _DashboardDemoScreenState
    extends State<DashboardDemoScreen> {
  int currentIndex = 0;

  final Child child = Child(
    id: '1',
    name: 'ليان',
    age: 8,
    schoolGrade: 'الصف الثالث',
    interests: [
      'الرسم',
      'القراءة',
    ],
    learningGoals: [
      'تحسين القراءة',
      'الرياضيات',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                const Text(
                  'مرحبًا بك 👋',
                  style: TextStyle(
                    color: Color(0xFF8A94AA),
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'كيف حال عائلتك اليوم؟',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                ChildCard(
                  child: child,
                  onTap: () {},
                ),

                const SizedBox(height: 25),

                const Text(
                  'ملخص اليوم',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'وقت الشاشة',
                        value: '2س 15د',
                        subtitle: 'من 3 ساعات',
                        icon: Icons.smartphone_rounded,
                        iconColor: const Color(0xFFFF624E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'التعلم',
                        value: '1س 20د',
                        subtitle: 'هذا اليوم',
                        icon: Icons.menu_book_rounded,
                        iconColor: const Color(0xFF62D9D4),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'النوم',
                        value: '8س 10د',
                        subtitle: 'الليلة الماضية',
                        icon: Icons.bedtime_rounded,
                        iconColor: const Color(0xFF7C89B8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'النقاط',
                        value: '250',
                        subtitle: 'نقطة',
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFFB84D),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3B63),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: const Color(0xFF62D9D4),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF2E3B63),
                          size: 30,
                        ),
                      ),

                      const SizedBox(width: 15),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مساعد التربية الذكي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'اسألني أي شيء عن تربية طفلك',
                              style: TextStyle(
                                color: Color(0xFFD8DDEC),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'نشاط اليوم 🎯',
                  style: TextStyle(
                    color: Color(0xFF2E3B63),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎨 اصنع قصة مصورة',
                        style: TextStyle(
                          color: Color(0xFF2E3B63),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'نشاط إبداعي مناسب لعمر 8 سنوات',
                        style: TextStyle(
                          color: Color(0xFF8A94AA),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '⏱ 30 دقيقة   •   ✏️ قلم وألوان',
                        style: TextStyle(
                          color: Color(0xFF62AFAF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: currentIndex,
          onTap: (index) {
            setState(() {
              currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}