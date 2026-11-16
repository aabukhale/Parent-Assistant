import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/providers.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/main.dart';

import 'support/fake_secure_storage.dart';

Widget _app({String locale = 'ar', FakeSecureTokenStorage? storage}) =>
    ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(
          storage ?? FakeSecureTokenStorage(),
        ),
        initialLocaleProvider.overrideWithValue(Locale(locale)),
      ],
      child: const MamilyApp(),
    );

void main() {
  testWidgets('unauthenticated launch offers the parent and child ways in', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final l = lookupAppLocalizations(const Locale('ar'));
    expect(find.text(l.roleParent), findsOneWidget);
    expect(find.text(l.roleChild), findsOneWidget);
    // No parked child session on a fresh install.
    expect(find.text(l.roleResumeChild), findsNothing);
  });

  testWidgets('"I\'m a parent" leads to sign in / create account', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('ar'));

    await tester.tap(find.text(l.roleParent));
    await tester.pumpAndSettle();

    expect(find.text(l.authLoginAction), findsOneWidget);
    expect(find.text(l.authCreateAccount), findsOneWidget);
  });

  testWidgets('"I\'m a child" leads to pairing', (tester) async {
    await tester.pumpWidget(_app(locale: 'en'));
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));

    await tester.tap(find.text(l.roleChild));
    await tester.pumpAndSettle();

    expect(find.text(l.pairTitle), findsOneWidget);
    expect(find.text(l.pairButton), findsOneWidget);
  });

  testWidgets('a parked child session offers a way back', (tester) async {
    await tester.pumpWidget(
      _app(
        locale: 'en',
        storage: FakeSecureTokenStorage(parkedChildToken: 'child-token'),
      ),
    );
    await tester.pumpAndSettle();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.roleResumeChild), findsOneWidget);
  });
}
