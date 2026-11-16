import 'package:flutter/material.dart';

import '../theme/mamily_colors.dart';

/// The illustrated identities a child can choose (keys mirror the backend
/// `ChildAvatar` enum). Rendered as large emoji on a soft disc so they stay
/// crisp at any size and need no image assets.
class ChildAvatars {
  const ChildAvatars._();

  static const Map<String, String> emoji = {
    'fox': '🦊',
    'bear': '🐻',
    'owl': '🦉',
    'cat': '🐱',
    'bunny': '🐰',
    'panda': '🐼',
    'lion': '🦁',
    'whale': '🐳',
    'dino': '🦕',
    'robot': '🤖',
    'unicorn': '🦄',
    'astronaut': '🧑‍🚀',
  };

  static List<String> get keys => emoji.keys.toList(growable: false);

  /// A stable fill for a child: their chosen colour if it parses, else one
  /// derived from their id so siblings look different without any setup.
  static Color fillFor({String? colorHex, String? seed}) {
    final parsed = _parse(colorHex);
    if (parsed != null) return parsed;
    final fills = MamilyPalette.avatarFills;
    final hash = (seed ?? '').codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    return fills[hash % fills.length];
  }

  static Color? _parse(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

/// A child's avatar: chosen emoji identity, or their initial as a fallback.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    this.avatarKey,
    this.colorHex,
    this.seed,
    this.size = 48,
    this.ring,
  });

  final String name;
  final String? avatarKey;
  final String? colorHex;
  final String? seed;
  final double size;

  /// Optional outline (e.g. selected child).
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final emoji = ChildAvatars.emoji[avatarKey];
    final fill = ChildAvatars.fillFor(colorHex: colorHex, seed: seed ?? name);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: ring == null ? null : Border.all(color: ring!, width: 3),
        ),
        child: emoji != null
            ? Text(
                emoji,
                style: TextStyle(fontSize: size * 0.52, height: 1),
                textScaler: TextScaler.noScaling,
              )
            : Text(
                initial,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  color: MamilyPalette.navy800,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
