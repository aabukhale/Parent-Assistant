// UI helpers shared by the real-backend integration suites.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/storage/secure_token_storage.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/main.dart' as app;

import 'backend.dart';

final l = lookupAppLocalizations(const Locale('en'));

/// `finder.first`/`.last` throw while nothing matches yet; treat that as
/// "not there yet".
bool found(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (found(finder)) return;
  }
  throw TestFailure(
    'Timed out waiting for ${finder.describeMatch(Plurality.zero)}',
  );
}

Future<T> eventually<T>(
  Future<T> Function() read,
  bool Function(T) ok, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  late T last;
  while (DateTime.now().isBefore(end)) {
    last = await read();
    if (ok(last)) return last;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return last;
}

/// The child app, paired to Omar. The first test pairs a fresh install
/// through the real pairing screen; later tests relaunch the app and reuse
/// that session (as a real phone would), which also keeps a full run under
/// the backend's pairing rate limit (5/min, 30/h per IP).
Future<void> launchAsChild(
  WidgetTester tester,
  ParentApi parent,
  String childId,
) async {
  final storage = SecureTokenStorage();
  final paired =
      await storage.readSessionKind() == 'child' &&
      await storage.readToken() != null;
  if (!paired) {
    await storage.clearEverything();
    await storage.writeLocale('en');
  }
  await app.main();
  if (paired) {
    await pumpUntil(tester, find.text(l.kidTabToday));
    return;
  }
  final code = await parent.pairingCode(childId);
  await pumpUntil(tester, find.text(l.roleChild));
  await tester.tap(find.text(l.roleChild));
  await pumpUntil(tester, find.text(l.pairButton));
  await tester.enterText(find.byType(TextField).first, code);
  await tester.tap(find.text(l.pairButton));
  await pumpUntil(tester, find.text(l.kidTabToday));
}

/// Scrolls the page's main list until [text] is on screen; returns its last
/// match (a title can also appear in the "next step" hero).
Future<Finder> scrollTo(WidgetTester tester, String text) async {
  await pumpUntil(tester, find.byType(Scrollable));
  final target = find.text(text);
  for (var i = 0; i < 40 && !found(target); i++) {
    await tester.drag(
      find.byType(Scrollable).hitTestable().first,
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await pumpUntil(tester, target);
  await tester.ensureVisible(target.last);
  await tester.pump(const Duration(milliseconds: 300));
  return target.last;
}
