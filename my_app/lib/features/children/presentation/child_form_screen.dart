import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdit ? l.childEditTitle : l.childAddTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
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
                const SizedBox(height: 18),
                _Label(l.childFieldBirthDate),
                const SizedBox(height: 8),
                _DateField(
                  date: _birthDate,
                  agePreview: _agePreview,
                  placeholder: l.childFieldBirthDatePick,
                  ageLabel: (age) => l.childAgeYears(age),
                  onTap: _pickDate,
                ),
                AuthFieldError(messages: _fieldErrors['birth_date']),
                const SizedBox(height: 18),
                _Label(l.childFieldGender),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final g in ChildGender.values)
                      ChoiceChip(
                        label: Text(_genderLabel(l, g)),
                        selected: _gender == g,
                        onSelected: (sel) =>
                            setState(() => _gender = sel ? g : null),
                        selectedColor: AppColors.teal,
                      ),
                  ],
                ),
                AuthFieldError(messages: _fieldErrors['gender']),
                const SizedBox(height: 18),
                _Label(l.childFieldAvatarColor),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final hex in _palette) ...[
                      _ColorDot(
                        hex: hex,
                        selected: _avatarColor == hex,
                        onTap: () => setState(
                          () => _avatarColor = _avatarColor == hex ? null : hex,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
                AuthFieldError(messages: _fieldErrors['avatar_color']),
                const SizedBox(height: 18),
                _Label(l.childFieldInterests),
                const SizedBox(height: 8),
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
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.coral),
                    ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.agePreview,
    required this.placeholder,
    required this.ageLabel,
    required this.onTap,
  });

  final DateTime? date;
  final int? agePreview;
  final String placeholder;
  final String Function(int age) ageLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: Color(0xFF8E98AC)),
            const SizedBox(width: 12),
            Text(
              date == null ? placeholder : ChildInput.formatDate(date!),
              style: TextStyle(
                color: date == null ? const Color(0xFF9AA3B5) : AppColors.navy,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (agePreview != null)
              Text(
                ageLabel(agePreview!),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.border,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: AppColors.navy)
            : null,
      ),
    );
  }
}

Color _parseHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return AppColors.teal;
  return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
}
