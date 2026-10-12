import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../application/children_controller.dart';
import '../data/child_requests.dart';
import '../data/interests_repository.dart';
import '../data/models/child.dart';
import '../data/models/interest.dart';
import 'interest_selector.dart';

/// Create (when [existing] is null) or edit a child.
///
/// - age input is a **date picker** → `birth_date`; the computed age is shown
/// - interests submit UUIDs, never names
/// - `avatar_color` is picked from a small preset palette (UI colour only)
class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({super.key, this.existing});

  final Child? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  static const _palette = <String>[
    '#FFE4DF',
    '#E4F4F3',
    '#E7E9F6',
    '#FFF1D9',
    '#E9F7E4',
    '#F6E4F0',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  DateTime? _birthDate;
  ChildGender? _gender;
  late Set<String> _interestIds;
  String? _avatarColor;

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _birthDate = e?.birthDate;
    _gender = e?.gender;
    _interestIds = {...?e?.interestIds};
    _avatarColor = e?.avatarColor;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DateTime get _minBirthDate => DateTime.now()
      .subtract(const Duration(days: 365 * 18))
      .add(const Duration(days: 1));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: _minBirthDate,
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  int? get _agePreview {
    final d = _birthDate;
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age < 0 ? 0 : age;
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    final formOk = _formKey.currentState!.validate();
    if (_birthDate == null) {
      setState(
        () => _fieldErrors = {
          'birth_date': [context.l10n.childValidationBirthDateRequired],
        },
      );
      return;
    }
    if (!formOk) return;

    final input = ChildInput(
      name: _name.text.trim(),
      birthDate: _birthDate!,
      gender: _gender,
      avatarColor: _avatarColor,
      interestIds: _interestIds.toList(),
    );

    setState(() => _submitting = true);
    try {
      final controller = ref.read(childrenControllerProvider.notifier);
      final child = widget.isEdit
          ? await controller.updateChild(widget.existing!.id, input)
          : await controller.createChild(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? context.l10n.childUpdated
                : context.l10n.childCreated,
          ),
        ),
      );
      Navigator.of(context).pop(child);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isValidation) {
          _fieldErrors = e.fieldErrors;
          if (_fieldErrors.isEmpty) {
            _formError = e.localizedMessage(context.l10n);
          }
        } else {
          _formError = e.localizedMessage(context.l10n);
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final interestsAsync = ref.watch(interestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? l.childEditTitle : l.childAddTitle),
      ),
      body: AppContentFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_formError != null)
                  AuthFormErrorBanner(message: _formError!),
                AppTextField(
                  label: l.childFieldName,
                  hint: l.childFieldNameHint,
                  controller: _name,
                  prefixIcon: Icons.face_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['name']),
                FormSectionLabel(l.childFieldBirthDate),
                PickerField(
                  icon: Icons.cake_outlined,
                  label: l.childFieldBirthDatePick,
                  value: _birthDate == null
                      ? null
                      : ChildInput.formatDate(_birthDate!),
                  trailing: _agePreview == null
                      ? null
                      : l.childAgeYears(_agePreview!),
                  onTap: _pickDate,
                ),
                AuthFieldError(messages: _fieldErrors['birth_date']),
                FormSectionLabel(l.childFieldGender),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in ChildGender.values)
                      ChoiceChip(
                        label: Text(_genderLabel(l, g)),
                        selected: _gender == g,
                        onSelected: (sel) =>
                            setState(() => _gender = sel ? g : null),
                      ),
                  ],
                ),
                AuthFieldError(messages: _fieldErrors['gender']),
                FormSectionLabel(l.childFieldAvatarColor),
                Wrap(
                  children: [
                    for (var i = 0; i < _palette.length; i++)
                      _ColorDot(
                        hex: _palette[i],
                        label: '${l.childFieldAvatarColor} ${i + 1}',
                        selected: _avatarColor == _palette[i],
                        onTap: () => setState(
                          () => _avatarColor = _avatarColor == _palette[i]
                              ? null
                              : _palette[i],
                        ),
                      ),
                  ],
                ),
                AuthFieldError(messages: _fieldErrors['avatar_color']),
                FormSectionLabel(l.childFieldInterests),
                InterestSelector(
                  interests: interestsAsync,
                  selected: _interestIds,
                  onToggle: (Interest i) => setState(() {
                    if (_interestIds.contains(i.id)) {
                      _interestIds.remove(i.id);
                    } else {
                      _interestIds.add(i.id);
                    }
                  }),
                  onRetry: () => ref.invalidate(interestsProvider),
                ),
                AuthFieldError(messages: _fieldErrors['interest_ids']),
                const SizedBox(height: 30),
                PrimaryButton(
                  text: l.childSave,
                  onPressed: _submitting ? null : _submit,
                ),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _genderLabel(AppLocalizations l, ChildGender g) => switch (g) {
    ChildGender.male => l.childGenderMale,
    ChildGender.female => l.childGenderFemale,
    ChildGender.unspecified => l.childGenderUnspecified,
  };
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String hex;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mamily;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox.square(
          dimension: AppSizes.minTouchTarget,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _parseHex(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.ink : c.borderStrong,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 20, color: c.ink)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return MamilyPalette.decorTeal;
  return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
}
