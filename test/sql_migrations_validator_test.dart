// ==============================================================================
// ZankoAI SQL Migrations Validation Test
// Validates:
// 1. Naming format (14-digit timestamp YYYYMMDDHHMMSS_*.sql)
// 2. Monotonic timestamp sequence (strictly ascending order)
// 3. Destructive safety guards (DROP statements must use IF EXISTS)
// ==============================================================================

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase SQL Migrations Validation', () {
    final migrationsDir = Directory('supabase/migrations');

    test('migrations directory exists', () {
      expect(
        migrationsDir.existsSync(),
        isTrue,
        reason: 'supabase/migrations directory must exist',
      );
    });

    final files =
        migrationsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('contains SQL migration files', () {
      expect(files.isNotEmpty, isTrue);
      expect(files.length, greaterThanOrEqualTo(24));
    });

    test(
      'all migration filenames follow YYYYMMDDHHMMSS_name.sql naming format',
      () {
        final pattern = RegExp(r'^\d{14}_[a-zA-Z0-9_]+\.sql$');
        for (final file in files) {
          final name = file.uri.pathSegments.last;
          expect(
            pattern.hasMatch(name),
            isTrue,
            reason:
                'File $name does not match naming format YYYYMMDDHHMMSS_name.sql',
          );
        }
      },
    );

    test('migration timestamps are strictly monotonic and sequential', () {
      String? lastTimestamp;
      for (final file in files) {
        final name = file.uri.pathSegments.last;
        final timestamp = name.substring(0, 14);

        if (lastTimestamp != null) {
          expect(
            timestamp.compareTo(lastTimestamp) > 0,
            isTrue,
            reason:
                'Migration $name ($timestamp) is not strictly greater than previous ($lastTimestamp)',
          );
        }
        lastTimestamp = timestamp;
      }
    });

    test('destructive DROP statements have safe IF EXISTS guards', () {
      final dropPattern = RegExp(
        r'^\s*DROP\s+(TABLE|INDEX|POLICY|VIEW|TYPE)\s+',
        caseSensitive: false,
        multiLine: true,
      );
      final ifExistsPattern = RegExp(r'IF\s+EXISTS', caseSensitive: false);

      final violations = <String>[];

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (dropPattern.hasMatch(line) && !ifExistsPattern.hasMatch(line)) {
            violations.add('${file.uri.pathSegments.last}:${i + 1} -> $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Unguarded DROP statements found without IF EXISTS:\n${violations.join('\n')}',
      );
    });
  });
}
