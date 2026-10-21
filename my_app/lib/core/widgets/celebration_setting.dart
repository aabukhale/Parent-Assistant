import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'celebration.dart';

/// "Celebrations" on/off, persisted per device and mirrored into
/// [Celebration.enabled].
class CelebrationsSetting extends StateNotifier<bool> {
  CelebrationsSetting(this._ref) : super(true) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    try {
      final on = await _ref.read(secureStorageProvider).readCelebrations();
      Celebration.enabled = on;
      if (mounted) state = on;
    } catch (_) {}
  }

  Future<void> set(bool on) async {
    state = on;
    Celebration.enabled = on;
    try {
      await _ref.read(secureStorageProvider).writeCelebrations(on);
    } catch (_) {}
  }
}

final celebrationsEnabledProvider =
    StateNotifierProvider<CelebrationsSetting, bool>(CelebrationsSetting.new);
