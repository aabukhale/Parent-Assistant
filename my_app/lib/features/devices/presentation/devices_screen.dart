import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
import '../application/devices_controller.dart';
import '../data/devices_repository.dart';
import '../data/models/device.dart';

/// Registered devices for the active family (`GET/POST/PATCH/DELETE …/devices`).
/// Replaces nothing that existed — Anwar's design had no device screen. Reached
/// from the screen-time screen.
///
/// Registration records **this install** with an app-generated identifier so a
/// future native Child Mode can bind to it. It does **not** give this app any
/// control over the device.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(devicesControllerProvider);
    final controller = ref.read(devicesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.devicesTitle)),
      body: AppContentFrame(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: async.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingView(),
            error: (e, _) => ListView(
              children: [
                const SizedBox(height: 120),
                ErrorRetryView(error: e, onRetry: controller.refresh),
              ],
            ),
            data: (state) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                NoticeBanner(tone: AppTone.info, message: l.devicesNote),
                const SizedBox(height: AppSpacing.md),
                if (state.isEmpty)
                  EmptyView(
                    icon: Icons.smartphone_rounded,
                    message: l.devicesEmpty,
                  )
                else
                  for (final d in state.devices)
                    _DeviceTile(
                      device: d,
                      onRevoke: () => _revoke(context, ref, d),
                      onRemove: () => _remove(context, ref, d),
                    ),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: OutlinedButton(
                      onPressed: controller.loadMore,
                      child: Text(l.devicesLoadMore),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => _register(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.devicesRegisterThis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DevicePlatform _thisPlatform() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => DevicePlatform.ios,
    TargetPlatform.android => DevicePlatform.android,
    _ => DevicePlatform.web,
  };

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_RegisterResult>(
      context: context,
      builder: (_) => const _RegisterDialog(),
    );
    if (result == null) return;
    try {
      await ref
          .read(devicesControllerProvider.notifier)
          .registerThisInstall(
            name: result.name,
            platform: _thisPlatform(),
            deviceMode: result.mode,
          );
      messenger.showSnackBar(SnackBar(content: Text(l.devicesRegistered)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, Device d) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(devicesControllerProvider.notifier)
          .updateDevice(d.id, DeviceUpdateInput(isActive: !d.isActive));
      messenger.showSnackBar(
        SnackBar(
          content: Text(d.isActive ? l.devicesRevoked : l.devicesReactivated),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Device d) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: l.devicesRemoveTitle,
      body: l.devicesRemoveBody(d.name),
      confirmLabel: l.devicesRemoveAction,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(devicesControllerProvider.notifier).remove(d.id);
      messenger.showSnackBar(SnackBar(content: Text(l.devicesRemoved)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localizedMessage(l))));
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onRevoke,
    required this.onRemove,
  });

  final Device device;
  final VoidCallback onRevoke;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = device;
    final modeLabel = switch (d.deviceMode) {
      DeviceMode.childDedicated => l.devicesModeChildDedicated,
      DeviceMode.familyShared => l.devicesModeFamilyShared,
      DeviceMode.unknown => '—',
    };
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          IconBadge(
            icon: d.platform == DevicePlatform.ios
                ? Icons.phone_iphone_rounded
                : d.platform == DevicePlatform.android
                ? Icons.phone_android_rounded
                : Icons.devices_rounded,
            tone: d.isActive ? AppTone.info : AppTone.neutral,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: context.type.labelLarge?.copyWith(
                    color: d.isActive
                        ? context.mamily.ink
                        : context.mamily.ink2,
                  ),
                ),
                Text(
                  d.isActive
                      ? modeLabel
                      : '$modeLabel · ${l.devicesRevokedTag}',
                  style: context.type.bodySmall?.copyWith(
                    color: context.mamily.ink2,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: d.name,
            icon: Icon(Icons.more_vert_rounded, color: context.mamily.ink2),
            onSelected: (v) => v == 'remove' ? onRemove() : onRevoke(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'revoke',
                child: Text(d.isActive ? l.devicesRevoke : l.devicesReactivate),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text(l.devicesRemoveAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegisterResult {
  const _RegisterResult({required this.name, required this.mode});
  final String name;
  final DeviceMode mode;
}

class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog();

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final _name = TextEditingController();
  DeviceMode _mode = DeviceMode.familyShared;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.devicesRegisterThis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l.devicesFieldName),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<DeviceMode>(
            segments: [
              ButtonSegment(
                value: DeviceMode.familyShared,
                label: Text(l.devicesModeFamilyShared),
              ),
              ButtonSegment(
                value: DeviceMode.childDedicated,
                label: Text(l.devicesModeChildDedicated),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        TextButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(_RegisterResult(name: name, mode: _mode));
          },
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
