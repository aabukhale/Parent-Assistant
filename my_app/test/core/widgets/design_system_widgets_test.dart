import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/design_system.dart';

Widget _app(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: direction == TextDirection.rtl
        ? const Locale('ar')
        : const Locale('en'),
    builder: (context, app) => Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
    ),
    home: child,
  );
}

Widget _page(Widget child) =>
    Scaffold(body: SingleChildScrollView(child: child));

void main() {
  group('Existing screens', () {
    testWidgets('plain Text renders in Rubik under the theme', (tester) async {
      await tester.pumpWidget(_app(_page(const Text('legacy'))));
      final style = tester
          .widget<RichText>(
            find.descendant(
              of: find.text('legacy'),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style;
      expect(style?.fontFamily, AppTypography.fontFamily);
    });

    testWidgets('design-system components render in Rubik', (tester) async {
      await tester.pumpWidget(
        _app(_page(const StatusPill(label: 'Done', tone: AppTone.success))),
      );
      final style = tester
          .widget<RichText>(
            find.descendant(
              of: find.text('Done'),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style;
      expect(style?.fontFamily, 'Rubik');
      expect(style?.fontWeight, isNotNull);
    });
  });

  group('AppCard', () {
    testWidgets('a tappable card responds, is a button and is >= 48dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(_page(AppCard(onTap: () => taps++, child: const Text('Tasks')))),
      );

      expect(
        tester.getSize(find.byType(AppCard)).height,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
      final node = tester.getSemantics(find.byType(AppCard));
      expect(node.flagsCollection.isButton, isTrue);

      await tester.tap(find.byType(AppCard));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a plain card is not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(_page(const AppCard(child: Text('Static')))),
      );
      expect(find.bySemanticsLabel('Static'), findsOneWidget);
      final node = tester.getSemantics(find.text('Static'));
      expect(node.flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('semanticLabel replaces child text and keeps the tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          _page(
            AppCard(
              onTap: () => taps++,
              semanticLabel: 'Points, 120',
              child: const Text('120'),
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppCard));
      expect(node.label, 'Points, 120');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('tone tints the card', (tester) async {
      await tester.pumpWidget(
        _app(_page(const AppCard(tone: AppTone.success, child: Text('Done')))),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, MamilyColors.light.success.background);
    });
  });

  group('SectionHeader', () {
    testWidgets('is a heading and its action works', (tester) async {
      final handle = tester.ensureSemantics();
      var tapped = false;
      await tester.pumpWidget(
        _app(
          _page(
            SectionHeader(
              title: 'Children',
              subtitle: '2 in this family',
              actionLabel: 'See all',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('2 in this family'), findsOneWidget);
      final heading = tester.getSemantics(find.text('Children'));
      expect(heading.flagsCollection.isHeader, isTrue);

      await tester.tap(find.text('See all'));
      expect(tapped, isTrue);
      handle.dispose();
    });

    test('rejects an action label without a callback', () {
      expect(
        () => SectionHeader(title: 'x', actionLabel: 'y'),
        throwsAssertionError,
      );
    });

    test('rejects trailing together with an action', () {
      expect(
        () => SectionHeader(
          title: 'x',
          actionLabel: 'y',
          onAction: () {},
          trailing: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });

  group('StatTile', () {
    testWidgets('shows value and label, reads them as one item', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _page(
            const StatTile(
              label: 'Points',
              value: '120',
              icon: Icons.star_rounded,
              tone: AppTone.warning,
            ),
          ),
        ),
      );
      expect(find.text('120'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      final node = tester.getSemantics(find.text('120'));
      expect(node.label, allOf(contains('120'), contains('Points')));
      handle.dispose();
    });

    testWidgets('onTap makes it a >= 48dp button', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(_page(StatTile(label: 'Tasks', value: '3', onTap: () => taps++))),
      );
      await tester.tap(find.byType(StatTile));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(StatTile)).height,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
    });
  });

  group('StatusPill', () {
    testWidgets('status tones always show an icon and a word', (tester) async {
      const statusTones = {
        AppTone.success: Icons.check_circle_rounded,
        AppTone.warning: Icons.warning_amber_rounded,
        AppTone.danger: Icons.error_rounded,
        AppTone.info: Icons.info_rounded,
      };
      for (final e in statusTones.entries) {
        await tester.pumpWidget(
          _app(_page(StatusPill(label: 'Label', tone: e.key))),
        );
        expect(find.text('Label'), findsOneWidget, reason: '${e.key}');
        expect(find.byIcon(e.value), findsOneWidget, reason: '${e.key}');
      }
    });

    testWidgets('neutral has no icon unless given one', (tester) async {
      await tester.pumpWidget(_app(_page(const StatusPill(label: 'Draft'))));
      expect(find.byType(Icon), findsNothing);

      await tester.pumpWidget(
        _app(_page(const StatusPill(label: 'Draft', icon: Icons.edit_rounded))),
      );
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    });
  });

  group('NoticeBanner', () {
    testWidgets('shows title, message, icon and a working action', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _app(
          _page(
            NoticeBanner(
              tone: AppTone.warning,
              title: 'Heads up',
              message: 'Screen-time limits are not enforced on the device.',
              actionLabel: 'Learn more',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Heads up'), findsOneWidget);
      expect(find.textContaining('not enforced'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      await tester.tap(find.text('Learn more'));
      expect(tapped, isTrue);
    });

    testWidgets('danger banners are live regions, others are not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          _page(const NoticeBanner(tone: AppTone.danger, message: 'Failed')),
        ),
      );
      expect(
        tester.getSemantics(find.text('Failed')).flagsCollection.isLiveRegion,
        isTrue,
      );

      await tester.pumpWidget(_app(_page(const NoticeBanner(message: 'FYI'))));
      expect(
        tester.getSemantics(find.text('FYI')).flagsCollection.isLiveRegion,
        isFalse,
      );
      handle.dispose();
    });

    test('rejects an action label without a callback', () {
      expect(
        () => NoticeBanner(message: 'x', actionLabel: 'y'),
        throwsAssertionError,
      );
    });
  });

  group('AppScaffold', () {
    testWidgets('renders the title and body', (tester) async {
      await tester.pumpWidget(
        _app(const AppScaffold(title: 'Today', body: Text('Body'))),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('no app bar when there is no title, actions or leading', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const AppScaffold(body: Text('Body'))));
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('caps the body to 640dp on a tablet and centres it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          AppScaffold(
            title: 'Today',
            body: ListView(
              children: const [SizedBox(key: Key('row'), height: 40)],
            ),
          ),
        ),
      );
      final row = tester.getRect(find.byKey(const Key('row')));
      expect(row.width, AppSizes.maxContentWidth);
      expect(row.center.dx, closeTo(800, 0.5));
    });

    testWidgets('leaves phones untouched', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          AppScaffold(
            title: 'Today',
            body: ListView(
              children: const [SizedBox(key: Key('row'), height: 40)],
            ),
          ),
        ),
      );
      expect(tester.getRect(find.byKey(const Key('row'))).width, 400);
    });

    testWidgets('a scroll view keeps scrolling inside the capped column', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          AppScaffold(
            title: 'Today',
            body: ListView(
              children: [
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 60, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      expect(find.text('row 0'), findsNothing);
    });
  });

  // The same components, stressed the way real users stress them: an RTL
  // language and the largest text size on a narrow phone. Any overflow is
  // reported by the framework as an exception.
  for (final direction in TextDirection.values) {
    testWidgets('lays out at 200% text on a 320dp phone ($direction)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          direction: direction,
          textScale: 2,
          AppScaffold(
            title: 'Mamily',
            body: ListView(
              padding: AppSpacing.pagePadding,
              children: [
                SectionHeader(
                  title: 'A fairly long section heading that must wrap',
                  subtitle: 'And a subtitle that is also long enough to wrap',
                  actionLabel: 'See all',
                  onAction: () {},
                ),
                NoticeBanner(
                  tone: AppTone.warning,
                  title: 'A notice title that wraps',
                  message:
                      'A notice message long enough to need several lines '
                      'when the text is set to the largest size.',
                  actionLabel: 'Learn more',
                  onAction: () {},
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(
                      child: StatTile(
                        label: 'Pending approval',
                        value: '12h 30m',
                        icon: Icons.hourglass_bottom_rounded,
                        tone: AppTone.info,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Points this week',
                        value: '1,250',
                        icon: Icons.star_rounded,
                        tone: AppTone.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const StatusPill(
                  label: 'A long status label that must wrap',
                  tone: AppTone.success,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () {},
                  child: const Text('A tappable card with some body text'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  group('Flutter accessibility guidelines', () {
    Widget guidelinePage() => _app(
      AppScaffold(
        title: 'Guidelines',
        body: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            SectionHeader(
              title: 'Section',
              actionLabel: 'See all',
              onAction: () {},
            ),
            AppCard(onTap: () {}, child: const Text('Open tasks')),
            const SizedBox(height: AppSpacing.md),
            StatTile(label: 'Points', value: '120', onTap: () {}),
            const SizedBox(height: AppSpacing.md),
            NoticeBanner(
              message: 'Something to know',
              actionLabel: 'Details',
              onAction: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: () {}, child: const Text('Save')),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
            TextButton(onPressed: () {}, child: const Text('Skip')),
          ],
        ),
      ),
    );

    testWidgets('Android tap targets are at least 48x48', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(guidelinePage());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('iOS tap targets are at least 44x44', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(guidelinePage());
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('every tappable control has a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(guidelinePage());
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
