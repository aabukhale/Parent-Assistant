# Mamily design system (foundation)

Import everything from one place:

```dart
import 'package:my_app/core/design_system.dart';
```

Existing screens are **not** migrated yet. They keep working unchanged; screens
adopt the system one redesign step at a time.

## Rules

| Need | Use | Never |
|---|---|---|
| Colour | `context.mamily.*` (`MamilyColors`) | raw hex, `AppColors` (legacy) |
| Text style | `context.type.titleMedium` etc. | `TextStyle(fontSize: …)` |
| Spacing | `AppSpacing.*` (4-pt grid) | ad-hoc numbers |
| Radius | `AppRadii.small/medium/large/pill` | other radii |
| Card | `AppCard` | `GestureDetector` + `Container` |
| Status label | `StatusPill` | private per-screen pills |
| Inline message | `NoticeBanner` | private per-screen banners |
| Number tile | `StatTile` | private per-screen stat widgets |
| Group heading | `SectionHeader` | ad-hoc bold `Text` |
| Page | `AppScaffold` | a bare `Scaffold` + hand-styled `AppBar` |

## Colour tokens (light, shipped)

| Token | Value | Use |
|---|---|---|
| `ink` / `ink2` / `ink3` | `#2E3B63` / `#55607A` / `#626C87` | headings and body / secondary / captions |
| `action` + `onAction` | `#D43A26` + white | primary button fill (4.74:1) |
| `actionText` | `#B3311F` | coral **text or icons** (the fill is only 4.46:1 on the page background) |
| `borderStrong` | `#77819B` | input / outlined-button borders (≥ 3:1) |
| `focus` | `#0F766E` | focus ring |
| tones | `neutral brand accent success warning danger info sleep` | each a foreground/background/border trio, all ≥ 4.5:1 |

The bright brand hues (`MamilyPalette.decorTeal/Amber/Coral`) are **decorative
only**: never text, never a white-text fill.

Dark tokens (`MamilyColors.dark`) are prepared and contrast-tested but no dark
UI is wired up.

Every pair above is asserted in `test/core/theme/contrast_test.dart`.

## Typography (Rubik)

`assets/fonts/Rubik-Variable.ttf` covers Latin, Arabic and Hebrew. Nothing is
below 12sp, `letterSpacing` is always 0 (it breaks Arabic joining), and line
height is ≥ 1.25×. Never put text in a fixed-height box.

**Rubik is a variable font that defaults to Light and does not respond to a
plain `FontWeight.bold`.** So Rubik is applied only through `context.type`
styles (which set the weight axis) and the themed Material buttons, app bar,
dialogs, snackbars and inputs. Plain `Text` in existing screens stays in the
legacy font (`AppTypography.legacyFontFamily`). To make Rubik the app-wide
default, either bundle static weights or finish migrating screens, then pass
`rubikEverywhere: true` in `AppTheme`.

## Touch targets, layout, motion

* Minimum interactive size 48dp (`AppSizes.minTouchTarget`), 56dp for Kid View.
* `AppScaffold` caps the body at 640dp on wide screens; phones are untouched.
* Motion is short and calm (`AppMotion`); honour `disableAnimations` with
  `AppMotion.resolve`.
* Status is never colour-only: status tones carry an icon plus a word.

## Licence

`assets/fonts/OFL.txt` is the SIL Open Font License for Rubik and must ship
with the font.
