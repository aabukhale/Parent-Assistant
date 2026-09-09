import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/interest.dart';

/// Multi-select chips for the localized interests catalog. Selection is by
/// interest **UUID**; the chip label is the localized name.
class InterestSelector extends StatelessWidget {
  const InterestSelector({
    super.key,
    required this.interests,
    required this.selected,
    required this.onToggle,
    required this.onRetry,
  });

  final AsyncValue<List<Interest>> interests;
  final Set<String> selected;
  final void Function(Interest) onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return interests.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.coral,
            ),
          ),
        ),
      ),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              e is ApiException
                  ? e.localizedMessage(l)
                  : l.childValidationInterests,
              style: const TextStyle(color: AppColors.coral, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
      data: (list) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final interest in list)
            FilterChip(
              label: Text(interest.name),
              selected: selected.contains(interest.id),
              onSelected: (_) => onToggle(interest),
              selectedColor: AppColors.teal,
              backgroundColor: Colors.white,
              showCheckmark: false,
            ),
        ],
      ),
    );
  }
}
