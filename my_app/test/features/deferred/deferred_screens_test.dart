import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/ai_parenting/ai_parenting_screen.dart';
import 'package:my_app/features/nutrition/nutrition_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';

Widget _host(Widget home, {String locale = 'en'}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: Locale(locale),
  home: home,
);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  testWidgets('AI coach screen: honest unavailable, no chat input', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AiParentingScreen()));
    await tester.pumpAndSettle();
    expect(find.text(l.aiCoachUnavailableTitle), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Nutrition screen: honest unavailable, no input', (tester) async {
    await tester.pumpWidget(_host(const NutritionScreen()));
    await tester.pumpAndSettle();
    expect(find.text(l.nutritionUnavailableTitle), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('RTL smoke (Arabic)', (tester) async {
    final arL = lookupAppLocalizations(const Locale('ar'));
    await tester.pumpWidget(_host(const NutritionScreen(), locale: 'ar'));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(
        tester.element(find.text(arL.nutritionUnavailableTitle)),
      ),
      TextDirection.rtl,
    );
  });
}
