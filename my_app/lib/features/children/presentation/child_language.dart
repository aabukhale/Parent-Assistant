import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/localization/app_locales.dart';
import '../../../core/localization/l10n.dart';
import '../../auth/application/auth_controller.dart';
import '../application/children_controller.dart';
import '../data/models/child.dart';

/// Each language written in its own script, so it can be found by someone
/// who can't read the current UI language.
const childLanguageEndonyms = {'ar': 'العربية', 'he': 'עברית', 'en': 'English'};

String childLanguageName(AppLocalizations l, String? code) => switch (code) {
  'ar' => l.languageArabic,
  'he' => l.languageHebrew,
  'en' => l.languageEnglish,
  _ => code ?? '',
};

/// Subtitle for a child's "App language" setting: the language the child's
/// app actually shows, marked when it comes from the family default.
String childLanguageSummary(AppLocalizations l, Child child) {
  final effective = child.effectiveLanguage ?? child.preferredLanguage;
  if (child.preferredLanguage == null) {
    return l.childLanguageFamilyDefault(childLanguageName(l, effective));
  }
  return childLanguageName(l, effective);
}

/// The value chosen in [showChildLanguagePicker]: a language code, or this
/// marker to clear the child's own setting (family default).
const _familyDefault = '';

/// Parent picks the app language for one child. Saves only that child's
/// `preferred_language`; the parent's own language and siblings are
/// untouched. Returns true when something was saved.
Future<bool> showChildLanguagePicker(
  BuildContext context,
  WidgetRef ref,
  Child child,
) async {
  final l = context.l10n;
  final current = child.preferredLanguage ?? _familyDefault;
  final familyLanguage =
      ref.read(activeMembershipProvider)?.family.preferredLanguage ??
      (child.preferredLanguage == null ? child.effectiveLanguage : null) ??
      AppLocales.fallback.languageCode;
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Semantics(
                header: true,
                child: Text(l.childLanguageTitle, style: sheet.type.titleLarge),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Text(
                l.childLanguageHint(child.name),
                style: sheet.type.bodyMedium?.copyWith(
                  color: sheet.mamily.ink2,
                ),
              ),
            ),
            for (final loc in AppLocales.supported)
              _option(
                sheet,
                value: loc.languageCode,
                title: childLanguageEndonyms[loc.languageCode]!,
                titleDirection: AppLocales.isRtl(loc)
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                subtitle: childLanguageName(l, loc.languageCode),
                selected: current == loc.languageCode,
              ),
            _option(
              sheet,
              value: _familyDefault,
              title: l.childLanguageFamilyDefault(
                childLanguageName(l, familyLanguage),
              ),
              selected: current == _familyDefault,
            ),
          ],
        ),
      ),
    ),
  );
  if (selected == null || selected == current || !context.mounted) {
    return false;
  }
  try {
    await ref
        .read(childrenControllerProvider.notifier)
        .setChildLanguage(child.id, selected.isEmpty ? null : selected);
    if (context.mounted) {
      showResultSnack(context, l.childLanguageSaved(child.name));
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showResultSnack(context, e.localizedMessage(l));
    return false;
  }
}

Widget _option(
  BuildContext context, {
  required String value,
  required String title,
  required bool selected,
  String? subtitle,
  TextDirection? titleDirection,
}) => ListTile(
  minTileHeight: 56,
  selected: selected,
  title: Text(title, textDirection: titleDirection),
  subtitle: subtitle == null ? null : Text(subtitle),
  trailing: selected ? const Icon(Icons.check_rounded) : null,
  onTap: () => Navigator.of(context).pop(value),
);
