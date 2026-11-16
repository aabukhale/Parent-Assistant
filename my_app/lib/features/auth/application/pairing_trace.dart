import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Step-by-step record of how a scanned/typed pairing code was handled (link
/// received, waited for auth, screen opened, request sent, result), so a
/// failed scan on a real phone can be diagnosed afterwards.
///
/// Kept in memory and mirrored to `Documents/pairing_trace.log` (last 200
/// lines; readable with `xcrun devicectl device copy from`). Codes are masked
/// to their last two characters; nothing else private is written.
class PairingTrace {
  PairingTrace._();

  static final List<String> _lines = [];
  static Future<void> _pending = Future.value();

  static List<String> get lines => List.unmodifiable(_lines);

  static String mask(String? code) {
    if (code == null || code.isEmpty) return '-';
    if (code.length <= 2) return '**';
    return '${'*' * (code.length - 2)}${code.substring(code.length - 2)}';
  }

  static void log(String step) {
    final line = '${DateTime.now().toIso8601String()} $step';
    debugPrint('[pairing] $step');
    _lines.add(line);
    if (_lines.length > 200) _lines.removeAt(0);
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    final snapshot = '${_lines.join('\n')}\n';
    _pending = _pending.then((_) async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        await File('${dir.path}/pairing_trace.log').writeAsString(snapshot);
      } catch (_) {
        // No file system (tests) — the in-memory copy is enough.
      }
    });
  }
}
