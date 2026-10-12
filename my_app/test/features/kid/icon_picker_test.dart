import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/design_system.dart';
import 'package:my_app/features/kid/presentation/kid_widgets.dart';
import 'package:my_app/l10n/app_localizations.dart';

void main() {
  test('every pickable icon has a spoken label in en, ar and he', () {
    for (final code in ['en', 'ar', 'he']) {
      final l = lookupAppLocalizations(Locale(code));
      final labels = {for (final k in pickableIconKeys) k: iconLabel(l, k)};
      for (final e in labels.entries) {
        expect(e.value, isNot(e.key), reason: '$code: ${e.key}');
        expect(e.value.trim(), isNotEmpty, reason: '$code: ${e.key}');
      }
      expect(
        labels.values.toSet().length,
        pickableIconKeys.length,
        reason: '$code labels must be distinct',
      );
    }
  });

  testWidgets('the picker announces localized names, not keys', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  picked = await pickIconKey(context, current: 'bed'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(find.bySemanticsLabel(ar.iconBed), findsOneWidget);
    expect(find.bySemanticsLabel('bed'), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel(ar.iconBed)),
      matchesSemantics(
        label: ar.iconBed,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    await tester.tap(find.bySemanticsLabel(ar.iconPet));
    await tester.pumpAndSettle();
    expect(picked, 'pet');
    handle.dispose();
  });
}
