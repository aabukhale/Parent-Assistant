import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/main.dart';

import 'support/fake_secure_storage.dart';

void main() {
  testWidgets('unauthenticated launch shows the welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureTokenStorage()),
          initialLocaleProvider.overrideWithValue(const Locale('ar')),
        ],
        child: const MamilyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final l = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l.authCreateAccount), findsOneWidget);
    expect(find.text(l.authHaveAccount), findsOneWidget);
  });
}
