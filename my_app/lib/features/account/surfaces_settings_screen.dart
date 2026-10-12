import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../core/errors/api_exception.dart';
import '../../core/localization/l10n.dart';
import '../family_hub/application/hub_providers.dart';
import '../family_hub/data/hub_repository.dart';
import '../notifications/push/push_service.dart';
import '../surfaces/surface_sync.dart';

/// What the home-screen widget / Android floating card / Live Activity may
/// show, and turning the Android floating card on or off.
class SurfacesSettingsScreen extends ConsumerStatefulWidget {
  const SurfacesSettingsScreen({super.key});

  @override
  ConsumerState<SurfacesSettingsScreen> createState() =>
      _SurfacesSettingsScreenState();
}

class _SurfacesSettingsScreenState extends ConsumerState<SurfacesSettingsScreen>
    with WidgetsBindingObserver {
  bool _hasOverlayPermission = false;
  bool _overlayRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOverlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Returning from the system permission page re-checks the grant.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkOverlay();
  }

  Future<void> _checkOverlay() async {
    final sync = ref.read(surfaceSyncProvider);
    if (!sync.overlaySupported) return;
    final has = await sync.hasOverlayPermission();
    final running = await sync.isOverlayRunning();
    if (mounted) {
      setState(() {
        _hasOverlayPermission = has;
        _overlayRunning = running;
      });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final l = context.l10n;
    try {
      await ref.read(hubRepositoryProvider).saveNotificationPrefs({
        'surface_options': {key: value},
      });
      ref.invalidate(notificationPrefsProvider);
      await ref.read(surfaceSyncProvider).refresh();
    } on ApiException catch (e) {
      if (mounted) showResultSnack(context, e.localizedMessage(l));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.mamily;
    final prefs = ref.watch(notificationPrefsProvider);
    final sync = ref.watch(surfaceSyncProvider);
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(title: Text(l.surfacesTitle)),
      body: AppContentFrame(
        maxWidth: 680,
        child: prefs.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(notificationPrefsProvider),
          ),
          data: (p) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                l.surfacesIntro,
                style: context.type.bodyLarge?.copyWith(color: c.ink2),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (key, label) in [
                      ('show_child_names', l.surfacesShowNames),
                      ('show_task_counts', l.surfacesShowTasks),
                      ('show_pending_approvals', l.surfacesShowApprovals),
                      ('show_routine_progress', l.surfacesShowRoutine),
                      ('show_mood', l.surfacesShowMood),
                      ('show_points', l.surfacesShowPoints),
                    ])
                      SwitchListTile(
                        title: Text(label),
                        value: p.surfaceOptions[key] ?? false,
                        onChanged: (v) => _toggle(key, v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              NoticeBanner(tone: AppTone.info, message: l.surfacesWidgetHow),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.surfacesUpdatesHonest,
                style: context.type.bodySmall?.copyWith(color: c.ink2),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (sync.overlaySupported)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.overlayTitle, style: context.type.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l.overlayBody,
                        style: context.type.bodyMedium?.copyWith(color: c.ink2),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!_hasOverlayPermission) ...[
                        NoticeBanner(
                          tone: AppTone.warning,
                          message: l.overlayDenied,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: sync.openOverlayPermissionSettings,
                          child: Text(l.overlayGrant),
                        ),
                      ] else if (_overlayRunning)
                        OutlinedButton(
                          onPressed: () async {
                            await sync.stopOverlay();
                            await _checkOverlay();
                          },
                          child: Text(l.overlayStop),
                        )
                      else
                        FilledButton(
                          onPressed: () async {
                            // So its "turn off" notification can show.
                            await ref
                                .read(pushServiceProvider)
                                .requestLocalNotificationPermission();
                            await sync.startOverlay();
                            await _checkOverlay();
                          },
                          child: Text(l.overlayStart),
                        ),
                    ],
                  ),
                )
              else if (isIos)
                NoticeBanner(tone: AppTone.neutral, message: l.overlayIosNote),
            ],
          ),
        ),
      ),
    );
  }
}
