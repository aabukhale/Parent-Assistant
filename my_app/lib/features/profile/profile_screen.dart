import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            'حسابي',
            style: TextStyle(
              color: Color(0xFF2E3B63),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3B63),
                  borderRadius:
                      BorderRadius.circular(30),
                ),
                child: const Column(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor:
                          Color(0xFF62D9D4),
                      child: Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: Color(0xFF2E3B63),
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Anwar Abu Khaled',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'ولي أمر',
                      style: TextStyle(
                        color: Color(0xFFD8DDEC),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              _ProfileItem(
                icon: Icons.person_outline_rounded,
                title: 'تعديل الملف الشخصي',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const EditProfileScreen(),
                    ),
                  );
                },
              ),

              _ProfileItem(
                icon: Icons.notifications_none_rounded,
                title: 'الإشعارات',
                onTap: () {},
              ),

              _ProfileItem(
                icon: Icons.lock_outline_rounded,
                title: 'الخصوصية والأمان',
                onTap: () {},
              ),

              _ProfileItem(
                icon: Icons.language_rounded,
                title: 'اللغة',
                trailing: 'العربية',
                onTap: () {},
              ),

              _ProfileItem(
                icon: Icons.help_outline_rounded,
                title: 'المساعدة',
                onTap: () {},
              ),

              _ProfileItem(
                icon: Icons.info_outline_rounded,
                title: 'عن التطبيق',
                trailing: 'v1.0.0',
                onTap: () {},
              ),

              const SizedBox(height: 20),

              TextButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFFF624E),
                ),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: Color(0xFFFF624E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  const _ProfileItem({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF62D9D4),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2E3B63),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: Color(0xFF8A94AA),
                  fontSize: 12,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_rounded,
              size: 15,
              color: Color(0xFF8A94AA),
            ),
          ],
        ),
      ),
    );
  }
}