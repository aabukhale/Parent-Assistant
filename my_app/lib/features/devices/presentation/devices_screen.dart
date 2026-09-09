import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.devicesTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF1F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    l.devicesNote,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (state.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      l.devicesEmpty,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
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
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton(
                      onPressed: controller.loadMore,
                      child: Text(l.devicesLoadMore),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _register(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l.devicesRegisterThis),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                    ),
                  ),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.devicesRemoveTitle),
        content: Text(l.devicesRemoveBody(d.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l.devicesRemoveAction,
              style: const TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            d.platform == DevicePlatform.ios
                ? Icons.phone_iphone_rounded
                : d.platform == DevicePlatform.android
                ? Icons.phone_android_rounded
                : Icons.devices_rounded,
            color: d.isActive ? AppColors.navy : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: TextStyle(
                    color: d.isActive ? AppColors.navy : AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  d.isActive
                      ? modeLabel
                      : '$modeLabel · ${l.devicesRevokedTag}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textMuted,
            ),
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
          const SizedBox(height: 12),
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
