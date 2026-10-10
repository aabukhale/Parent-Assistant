import 'package:flutter/material.dart';

/// Full-width primary action, styled by the theme's FilledButton.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? FilledButton(onPressed: onPressed, child: Text(text))
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(text),
            ),
    );
  }
}
