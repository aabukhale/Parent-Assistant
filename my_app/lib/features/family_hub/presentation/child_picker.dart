import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system.dart';
import '../../children/application/selected_child_controller.dart';
import '../../children/data/models/child.dart';
import 'hub_widgets.dart';

/// Ask which child an action is for (skipped when there is only one). Also
/// selects that child for the existing per-child screens.
Future<Child?> pickChild(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) async {
  final children = ref.read(childLookupProvider).values.toList();
  if (children.isEmpty) return null;
  if (children.length == 1) {
    ref.read(selectedChildIdProvider.notifier).select(children.single.id);
    return children.single;
  }
  final picked = await showModalBottomSheet<Child>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: sheet.type.titleLarge),
            const SizedBox(height: AppSpacing.md),
            for (final c in children)
              ListTile(
                leading: ChildAvatarById(childId: c.id, size: 40),
                title: Text(c.name, style: sheet.type.titleSmall),
                onTap: () => Navigator.of(sheet).pop(c),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked != null) {
    ref.read(selectedChildIdProvider.notifier).select(picked.id);
  }
  return picked;
}
