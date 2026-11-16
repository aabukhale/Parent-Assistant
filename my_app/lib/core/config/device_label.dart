import 'package:flutter/foundation.dart';

/// A human-readable label for the Sanctum token (`device_name`, required by the
/// backend). We deliberately avoid a hardware identifier here — that belongs to
/// device registration (Phase 11), not token naming.
String currentDeviceLabel() {
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
  return 'Mamily ($platform)';
}

/// Label for a paired child install (shown to parents in "Devices").
String childDeviceLabel() {
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iPhone/iPad',
    _ => 'Device',
  };
  return 'Mamily ($platform)';
}
