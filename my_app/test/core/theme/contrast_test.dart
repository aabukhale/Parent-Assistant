import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/design_system.dart';

/// Every foreground/background pair the design system promises is checked
/// here, in both the shipped light tokens and the prepared dark tokens. If a
/// token is retuned and stops meeting WCAG AA, this fails.
void main() {
  group('Contrast helper', () {
    test('matches reference values', () {
      expect(Contrast.ratio(Colors.white, Colors.black), closeTo(21, 0.01));
      expect(Contrast.ratio(Colors.white, Colors.white), closeTo(1, 0.001));
      // Independently computed: navy on white 10.93, brand coral on white 2.95.
      expect(
        Contrast.ratio(MamilyPalette.navy800, Colors.white),
        closeTo(10.93, 0.01),
      );
      expect(
        Contrast.ratio(MamilyPalette.decorCoral, Colors.white),
        closeTo(2.95, 0.01),
      );
    });

    test('is symmetric', () {
      const a = Color(0xFFD43A26);
      expect(Contrast.ratio(a, Colors.white), Contrast.ratio(Colors.white, a));
    });

    test('bestOn picks the more readable candidate', () {
      expect(
        Contrast.bestOn(MamilyPalette.decorTeal, [
          Colors.white,
          MamilyPalette.navy800,
        ]),
        MamilyPalette.navy800,
      );
      expect(
        Contrast.bestOn(MamilyPalette.navy800, [
          Colors.white,
          MamilyPalette.navy800,
        ]),
        Colors.white,
      );
    });
  });

  for (final entry in {
    'light': MamilyColors.light,
    'dark': MamilyColors.dark,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    group('$name tokens', () {
      void expectText(Color fg, Color bg, String what) {
        final r = Contrast.ratio(fg, bg);
        expect(
          r,
          greaterThanOrEqualTo(Contrast.aaText),
          reason: '$what is ${r.toStringAsFixed(2)}:1, needs 4.5:1',
        );
      }

      void expectUi(Color fg, Color bg, String what) {
        final r = Contrast.ratio(fg, bg);
        expect(
          r,
          greaterThanOrEqualTo(Contrast.aaLargeOrUi),
          reason: '$what is ${r.toStringAsFixed(2)}:1, needs 3:1',
        );
      }

      test('body text is AA on every text surface', () {
        final surfaces = {
          'background': c.background,
          'surface': c.surface,
          'surfaceMuted': c.surfaceMuted,
        };
        for (final s in surfaces.entries) {
          expectText(c.ink, s.value, 'ink on ${s.key}');
          expectText(c.ink2, s.value, 'ink2 on ${s.key}');
          expectText(c.ink3, s.value, 'ink3 on ${s.key}');
          expectText(c.actionText, s.value, 'actionText on ${s.key}');
        }
        // surfaceStrong holds tracks, not captions.
        expectText(c.ink, c.surfaceStrong, 'ink on surfaceStrong');
        expectText(c.ink2, c.surfaceStrong, 'ink2 on surfaceStrong');
      });

      test('primary action label is AA on the action fill', () {
        expectText(c.onAction, c.action, 'onAction on action');
        expectText(c.onAction, c.actionPressed, 'onAction on actionPressed');
      });

      test('control boundaries and focus ring are at least 3:1', () {
        for (final s in [c.background, c.surface, c.surfaceMuted]) {
          expectUi(c.borderStrong, s, 'borderStrong on $s');
          expectUi(c.focus, s, 'focus on $s');
        }
        expectUi(c.action, c.surface, 'action fill on surface');
      });

      test('every tone is AA for its text on its tint and on the surface', () {
        for (final tone in AppTone.values) {
          final t = c.tone(tone);
          expectText(t.foreground, t.background, '$tone foreground on tint');
          expectText(t.foreground, c.surface, '$tone foreground on surface');
          expectText(t.foreground, c.background, '$tone on background');
          expectText(c.ink, t.background, 'ink on $tone tint');
        }
      });
    });
  }

  group('Brand and approved values', () {
    test('primary coral is the approved #D43A26 with white labels', () {
      expect(MamilyColors.light.action, const Color(0xFFD43A26));
      expect(MamilyColors.light.onAction, Colors.white);
    });

    test('coral text uses the darker token, not the button fill', () {
      // #D43A26 is 4.46:1 on the #F7F8FC page — fine for a filled button,
      // not for coral text. actionText exists for exactly this.
      expect(
        Contrast.ratio(
          MamilyColors.light.action,
          MamilyColors.light.background,
        ),
        lessThan(Contrast.aaText),
      );
      expect(
        Contrast.ratio(
          MamilyColors.light.actionText,
          MamilyColors.light.background,
        ),
        greaterThanOrEqualTo(Contrast.aaText),
      );
    });

    test('decorative brand hues are documented as decorative', () {
      // Dark ink is readable on teal and amber fills, but not on bright coral.
      expect(
        Contrast.ratio(MamilyPalette.navy800, MamilyPalette.decorTeal),
        greaterThanOrEqualTo(Contrast.aaText),
      );
      expect(
        Contrast.ratio(MamilyPalette.navy800, MamilyPalette.decorAmber),
        greaterThanOrEqualTo(Contrast.aaText),
      );
      expect(
        Contrast.ratio(MamilyPalette.navy800, MamilyPalette.decorCoral),
        lessThan(Contrast.aaText),
      );
      // ...and none of them work as a white-text fill.
      for (final d in [
        MamilyPalette.decorTeal,
        MamilyPalette.decorAmber,
        MamilyPalette.decorCoral,
      ]) {
        expect(Contrast.ratio(Colors.white, d), lessThan(Contrast.aaText));
      }
    });
  });

  group('ColorScheme derived from the tokens', () {
    final themes = {
      'light': AppTheme.light,
      // Dark is prepared but not shipped; it must still build and pass.
      'dark': AppTheme.buildFor(MamilyColors.dark),
    };

    for (final entry in themes.entries) {
      test('${entry.key}: every on-colour pair is AA', () {
        final s = entry.value.colorScheme;
        final pairs = <String, (Color, Color)>{
          'onPrimary/primary': (s.onPrimary, s.primary),
          'onPrimaryContainer/primaryContainer': (
            s.onPrimaryContainer,
            s.primaryContainer,
          ),
          'onSecondary/secondary': (s.onSecondary, s.secondary),
          'onSecondaryContainer/secondaryContainer': (
            s.onSecondaryContainer,
            s.secondaryContainer,
          ),
          'onTertiary/tertiary': (s.onTertiary, s.tertiary),
          'onTertiaryContainer/tertiaryContainer': (
            s.onTertiaryContainer,
            s.tertiaryContainer,
          ),
          'onError/error': (s.onError, s.error),
          'onErrorContainer/errorContainer': (
            s.onErrorContainer,
            s.errorContainer,
          ),
          'onSurface/surface': (s.onSurface, s.surface),
          'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
          'onInverseSurface/inverseSurface': (
            s.onInverseSurface,
            s.inverseSurface,
          ),
          // Snackbar action text.
          'inversePrimary/inverseSurface': (s.inversePrimary, s.inverseSurface),
        };
        for (final p in pairs.entries) {
          final r = Contrast.ratio(p.value.$1, p.value.$2);
          expect(
            r,
            greaterThanOrEqualTo(Contrast.aaText),
            reason: '${p.key} is ${r.toStringAsFixed(2)}:1',
          );
        }
      });
    }
  });
}
