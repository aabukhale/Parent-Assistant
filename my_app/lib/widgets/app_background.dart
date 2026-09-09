import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final bool darkHeader;
  final Widget child;

  const AppBackground({
    super.key,
    this.darkHeader = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: darkHeader
            ? const LinearGradient(
                colors: [Color(0xFF2E3B63), Color(0xFF3E4C7A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: darkHeader ? null : const Color(0xFFF7F8FC),
      ),
      child: child,
    );
  }
}
