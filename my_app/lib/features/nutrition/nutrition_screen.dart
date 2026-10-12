import 'package:flutter/material.dart';

import '../../core/localization/l10n.dart';
import '../../core/design_system.dart';

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
      appBar: AppBar(title: Text(l.nutritionTitle)),
      body: AppContentFrame(
        child: ComingSoonView(
          icon: Icons.restaurant_rounded,
          title: l.nutritionUnavailableTitle,
          body: l.nutritionUnavailableBody,
        ),
      ),
    );
  }
}
