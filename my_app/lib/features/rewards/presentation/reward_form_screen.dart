import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../auth/presentation/auth_form_widgets.dart';
import '../application/rewards_controller.dart';
import '../data/models/reward.dart';
import '../data/models/reward_enums.dart';
import '../data/reward_requests.dart';
import 'reward_widgets.dart';

/// Create (when [existing] is null) or edit a **family** reward. The reward
/// `type` is immutable after creation (the backend `UpdateRewardRequest` has no
/// `type` field). Global templates are never editable here.
class RewardFormScreen extends ConsumerStatefulWidget {
  const RewardFormScreen({super.key, this.existing});

  final Reward? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<RewardFormScreen> createState() => _RewardFormScreenState();
}

class _RewardFormScreenState extends ConsumerState<RewardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _cost;
  late final TextEditingController _minutes;

  RewardType _type = RewardType.privilege;
  bool _isActive = true;

  bool _submitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _formError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _cost = TextEditingController(text: e != null ? '${e.pointsCost}' : '50');
    _minutes = TextEditingController(
      text: e?.screenTimeMinutes != null ? '${e!.screenTimeMinutes}' : '30',
    );
    _type = e?.type ?? RewardType.privilege;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _cost.dispose();
    _minutes.dispose();
    super.dispose();
  }

  int? get _parsedCost => int.tryParse(_cost.text.trim());
  int? get _parsedMinutes => int.tryParse(_minutes.text.trim());

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = const {};
      _formError = null;
    });
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    final cost = _parsedCost;
    if (cost == null || cost < 1 || cost > 100000) {
      setState(
        () => _fieldErrors = {
          'points_cost': [l.rewardValidationCost],
        },
      );
      return;
    }
    if (_type == RewardType.screenTime) {
      final m = _parsedMinutes;
      if (m == null || m < 1 || m > 600) {
        setState(
          () => _fieldErrors = {
            'metadata.minutes': [l.rewardValidationMinutes],
          },
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final controller = ref.read(rewardsControllerProvider.notifier);
      if (widget.isEdit) {
        await controller.updateReward(
          widget.existing!.id,
          RewardUpdateInput.fromReward(
            widget.existing!,
            title: _title.text,
            description: _description.text,
            pointsCost: cost,
            isActive: _isActive,
            screenTimeMinutes: _type == RewardType.screenTime
                ? _parsedMinutes
                : null,
          ),
        );
      } else {
        await controller.createReward(
          RewardCreateInput(
            title: _title.text,
            description: _description.text,
            type: _type,
            pointsCost: cost,
            screenTimeMinutes: _type == RewardType.screenTime
                ? _parsedMinutes
                : null,
            isActive: _isActive,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? l.rewardUpdated : l.rewardCreated),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.isValidation) {
          _fieldErrors = e.fieldErrors;
          if (_fieldErrors.isEmpty) _formError = e.localizedMessage(l);
        } else {
          _formError = e.localizedMessage(l);
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdit ? l.rewardsEditTitle : l.rewardsNewTitle),
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
                  label: l.rewardFieldTitle,
                  hint: l.rewardFieldTitleHint,
                  controller: _title,
                  prefixIcon: Icons.card_giftcard_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['title']),
                const SizedBox(height: 16),
                AppTextField(
                  label: l.rewardFieldDescription,
                  controller: _description,
                  prefixIcon: Icons.notes_rounded,
                ),
                AuthFieldError(messages: _fieldErrors['description']),
                const SizedBox(height: 18),
                _label(l.rewardFieldType),
                const SizedBox(height: 8),
                if (widget.isEdit)
                  _ReadOnlyType(type: _type)
                else
                  _TypePicker(
                    value: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                AuthFieldError(messages: _fieldErrors['type']),
                if (_type == RewardType.screenTime) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    label: l.rewardFieldMinutes,
                    controller: _minutes,
                    prefixIcon: Icons.timelapse_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  AuthFieldError(messages: _fieldErrors['metadata.minutes']),
                ],
                const SizedBox(height: 16),
                AppTextField(
                  label: l.rewardFieldCost,
                  controller: _cost,
                  prefixIcon: Icons.stars_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l.validationRequired
                      : null,
                ),
                AuthFieldError(messages: _fieldErrors['points_cost']),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.rewardFieldActive),
                  value: _isActive,
                  activeThumbColor: AppColors.coral,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                AuthFieldError(messages: _fieldErrors['is_active']),
                const SizedBox(height: 22),
                PrimaryButton(
                  text: l.rewardSave,
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

  Widget _label(String text) => Align(
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

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.value, required this.onChanged});
  final RewardType value;
  final ValueChanged<RewardType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        for (final t in RewardType.values)
          GestureDetector(
            onTap: () => onChanged(t),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: value == t ? AppColors.coral : AppColors.border,
                  width: value == t ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    value == t
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: value == t ? AppColors.coral : AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Icon(rewardTypeIcon(t), size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Text(
                    rewardTypeLabel(l, t),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadOnlyType extends StatelessWidget {
  const _ReadOnlyType({required this.type});
  final RewardType type;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Icon(rewardTypeIcon(type), size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${rewardTypeLabel(l, type)} · ${l.rewardTypeLocked}',
              style: const TextStyle(color: AppColors.navy, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
