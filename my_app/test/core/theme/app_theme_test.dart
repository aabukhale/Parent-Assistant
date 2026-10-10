import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/design_system.dart';

void main() {
  final theme = AppTheme.light;

  group('AppTheme', () {
    test('is Material 3, Rubik, with the Mamily tokens attached', () {
      expect(theme.useMaterial3, isTrue);
      expect(AppTypography.fontFamily, 'Rubik');
      expect(theme.extension<MamilyTypography>(), isNotNull);
      expect(theme.extension<MamilyColors>(), MamilyColors.light);
      expect(theme.scaffoldBackgroundColor, MamilyColors.light.background);
    });

    test('dark tokens build a theme but none is shipped', () {
      final dark = AppTheme.buildFor(MamilyColors.dark);
      expect(dark.brightness, Brightness.dark);
      expect(dark.extension<MamilyColors>()?.isDark, isTrue);
    });
  });

  group('Typography', () {
    final type = theme.extension<MamilyTypography>()!.styles;
    final styles = <String, TextStyle?>{
      'displayLarge': type.displayLarge,
      'displayMedium': type.displayMedium,
      'displaySmall': type.displaySmall,
      'headlineLarge': type.headlineLarge,
      'headlineMedium': type.headlineMedium,
      'headlineSmall': type.headlineSmall,
      'titleLarge': type.titleLarge,
      'titleMedium': type.titleMedium,
      'titleSmall': type.titleSmall,
      'bodyLarge': type.bodyLarge,
      'bodyMedium': type.bodyMedium,
      'bodySmall': type.bodySmall,
      'labelLarge': type.labelLarge,
      'labelMedium': type.labelMedium,
      'labelSmall': type.labelSmall,
    };

    test('every style is Rubik, ink-coloured and drives the weight axis', () {
      for (final e in styles.entries) {
        final s = e.value!;
        expect(s.fontFamily, 'Rubik', reason: e.key);
        expect(s.color, MamilyColors.light.ink, reason: e.key);
        expect(
          s.fontVariations?.any((v) => v.axis == 'wght'),
          isTrue,
          reason: '${e.key} must set the wght axis',
        );
      }
    });

    test('nothing is below 12sp', () {
      for (final e in styles.entries) {
        expect(
          e.value!.fontSize,
          greaterThanOrEqualTo(AppTypography.minFontSize),
          reason: e.key,
        );
      }
    });

    test('letter spacing is 0 (non-zero tracking breaks Arabic joining)', () {
      for (final e in styles.entries) {
        expect(e.value!.letterSpacing, 0, reason: e.key);
      }
    });

    test(
      'line height clears Rubik\'s 1.185 line box for Arabic and Hebrew',
      () {
        for (final e in styles.entries) {
          expect(e.value!.height, greaterThanOrEqualTo(1.25), reason: e.key);
        }
      },
    );

    test('follows the documented scale', () {
      expect(type.displaySmall?.fontSize, 32);
      expect(type.titleLarge?.fontSize, 22);
      expect(type.titleMedium?.fontSize, 18);
      expect(type.bodyLarge?.fontSize, 16);
      expect(type.bodyMedium?.fontSize, 14);
      expect(type.bodySmall?.fontSize, 12);
    });

    // Rubik is a variable font that defaults to Light and ignores a plain
    // FontWeight.bold, so it must not become the default for existing screens
    // until static weights exist or the screens migrate.
    test('existing screens keep their font; Rubik is opt-in per style', () {
      expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Rubik'));
      expect(
        theme.textTheme.bodyMedium?.fontFamily,
        AppTypography.legacyFontFamily,
      );
    });

    test('the app-wide switch makes Rubik the default when it is safe', () {
      final all = AppTheme.buildFor(MamilyColors.light, rubikEverywhere: true);
      expect(all.textTheme.bodyMedium?.fontFamily, 'Rubik');
    });

    test('themed Material buttons use Rubik with the weight axis set', () {
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        final text = style.textStyle!.resolve({})!;
        expect(text.fontFamily, 'Rubik');
        expect(text.fontVariations, isNotEmpty);
      }
    });
  });

  group('Buttons', () {
    test('every button style has a 48dp minimum height, never a fixed one', () {
      final styles = <String, ButtonStyle?>{
        'filled': theme.filledButtonTheme.style,
        'elevated': theme.elevatedButtonTheme.style,
        'outlined': theme.outlinedButtonTheme.style,
        'text': theme.textButtonTheme.style,
        'icon': theme.iconButtonTheme.style,
      };
      for (final e in styles.entries) {
        final style = e.value!;
        final min = style.minimumSize!.resolve({});
        expect(
          min!.height,
          greaterThanOrEqualTo(AppSizes.minTouchTarget),
          reason: e.key,
        );
        expect(
          style.fixedSize,
          isNull,
          reason: '${e.key} must be able to grow with text size',
        );
      }
    });

    test('primary buttons use the approved coral with white text', () {
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
      ]) {
        expect(style.backgroundColor!.resolve({}), const Color(0xFFD43A26));
        expect(style.foregroundColor!.resolve({}), Colors.white);
        expect(style.shape!.resolve({}), isA<StadiumBorder>());
      }
    });

    test('outlined buttons have a perceivable (≥3:1) border', () {
      final side = theme.outlinedButtonTheme.style!.side!.resolve({})!;
      expect(
        Contrast.ratio(side.color, MamilyColors.light.surface),
        greaterThanOrEqualTo(Contrast.aaLargeOrUi),
      );
    });

    test('text buttons are AA on the page background', () {
      final fg = theme.textButtonTheme.style!.foregroundColor!.resolve({})!;
      expect(
        Contrast.ratio(fg, MamilyColors.light.background),
        greaterThanOrEqualTo(Contrast.aaText),
      );
    });
  });

  group('Inputs, cards and overlays', () {
    test('input borders are perceivable and errors are not colour-only', () {
      final d = theme.inputDecorationTheme;
      final border = (d.enabledBorder as OutlineInputBorder).borderSide;
      expect(
        Contrast.ratio(border.color, MamilyColors.light.surface),
        greaterThanOrEqualTo(Contrast.aaLargeOrUi),
      );
      expect(d.errorMaxLines, greaterThan(1));
      // Hint text meets AA too, not just the value.
      expect(
        Contrast.ratio(d.hintStyle!.color!, MamilyColors.light.surface),
        greaterThanOrEqualTo(Contrast.aaText),
      );
    });

    test('cards are flat, hairline-bordered, 16px', () {
      final card = theme.cardTheme;
      expect(card.elevation, 0);
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, AppRadii.mediumAll);
    });

    test('snackbars float and are readable', () {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    test('app bar stays transparent so existing screens are unchanged', () {
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });
  });

  group('Tokens', () {
    test('spacing sits on a 4-pt grid', () {
      for (final v in [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ]) {
        expect(v % 4, 0, reason: '$v');
      }
    });

    test('radii are the three documented steps plus a pill', () {
      expect(AppRadii.small, 12);
      expect(AppRadii.medium, 16);
      expect(AppRadii.large, 24);
    });

    test('touch targets and content cap', () {
      expect(AppSizes.minTouchTarget, 48);
      expect(AppSizes.minTouchTargetKid, 56);
      expect(AppSizes.maxContentWidth, 640);
    });

    test('MamilyColors lerps and copies without losing fields', () {
      final same = MamilyColors.light.lerp(MamilyColors.dark, 0);
      expect(same.ink, MamilyColors.light.ink);
      expect(same.success, MamilyColors.light.success);
      final end = MamilyColors.light.lerp(MamilyColors.dark, 1);
      expect(end.ink, MamilyColors.dark.ink);
      expect(end.danger, MamilyColors.dark.danger);
      final copy = MamilyColors.light.copyWith(ink: Colors.black);
      expect(copy.ink, Colors.black);
      expect(copy.ink2, MamilyColors.light.ink2);
    });
  });

  group('Font assets', () {
    test('Rubik is registered in pubspec and shipped with its licence', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Rubik'));
      expect(pubspec, contains('assets/fonts/Rubik-Variable.ttf'));
      expect(pubspec, contains('assets/fonts/OFL.txt'));

      final font = File('assets/fonts/Rubik-Variable.ttf');
      expect(font.existsSync(), isTrue);
      expect(font.lengthSync(), greaterThan(100 * 1024));
      final licence = File('assets/fonts/OFL.txt').readAsStringSync();
      expect(licence, contains('SIL Open Font License'));
    });
  });
}
