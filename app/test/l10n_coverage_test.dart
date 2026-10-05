import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every locale must translate every message of the English template and keep
/// its declared placeholders, so no screen silently falls back to English.
void main() {
  final dir = Directory('lib/l10n');
  final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
  final keys = en.keys.where((k) => !k.startsWith('@')).toList();
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb') && !f.path.endsWith('app_en.arb'));

  for (final file in files) {
    final locale = file.uri.pathSegments.last.replaceAll(RegExp(r'^app_|\.arb$'), '');
    test('$locale has every message and placeholder', () {
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final missing = keys.where((k) => !arb.containsKey(k)).toList();
      expect(missing, isEmpty, reason: '$locale is missing ${missing.length} keys');
      for (final k in keys) {
        final placeholders = ((en['@$k'] as Map?)?['placeholders'] as Map?)?.keys ?? const [];
        for (final name in placeholders) {
          expect(RegExp('\\{$name[},]').hasMatch(arb[k] as String), isTrue, reason: '$locale.$k lost {$name}');
        }
      }
    });
  }
}
