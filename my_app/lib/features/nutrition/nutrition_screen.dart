import 'package:flutter/material.dart';

import '../../core/localization/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/state_views.dart';

/// Nutrition / meal analysis. There is **no backend** for this — the Mamily API
/// has no nutrition, meal-log, or photo-analysis endpoint. Anwar's original
/// screen produced fabricated "smart" results locally; that (and the
/// `MealResultScreen`) has been removed. Locally entered meal or allergy data
/// would not persist anywhere, so no input is offered.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.nutritionTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ComingSoonView(
          icon: Icons.restaurant_rounded,
          title: l.nutritionUnavailableTitle,
          body: l.nutritionUnavailableBody,
        ),
      ),
    );
  }
}
