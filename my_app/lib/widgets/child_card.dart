import 'package:flutter/material.dart';
import '../models/child.dart';

class ChildCard extends StatelessWidget {
  final Child child;
  final VoidCallback? onTap;

  const ChildCard({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE6E1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: child.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        child.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.face_rounded,
                      size: 34,
                      color: Color(0xFFFF624E),
                    ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(
                      color: Color(0xFF2E3B63),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '${child.age} سنوات • ${child.schoolGrade}',
                    style: const TextStyle(
                      color: Color(0xFF8A94AA),
                      fontSize: 13,
                    ),
                  ),

                  if (child.interests.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      child.interests.take(2).join(' • '),
                      style: const TextStyle(
                        color: Color(0xFF62AFAF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF9AA3B5),
            ),
          ],
        ),
      ),
    );
  }
}