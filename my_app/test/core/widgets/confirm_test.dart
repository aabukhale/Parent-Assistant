import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/design_system.dart';
import 'package:my_app/l10n/app_localizations.dart';

void main() {
  testWidgets('a double tap opens one confirm sheet, not two', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(
                await confirmAction(
                  context,
                  title: 'Sure?',
                  confirmLabel: 'Yes',
                ),
              ),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );

    // Two presses before the sheet has even been laid out.
    final press = tester.widget<TextButton>(find.byType(TextButton)).onPressed!;
    press();
    press();
    await tester.pumpAndSettle();

    expect(find.text('Sure?'), findsOneWidget);
    expect(results, [false], reason: 'the second call is refused at once');

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
    expect(find.text('Sure?'), findsNothing);

    // Closed again, so the next call opens normally.
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.text('Sure?'), findsOneWidget);
  });
}
