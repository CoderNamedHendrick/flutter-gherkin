import 'dart:convert';
import 'dart:io';
import 'config.dart';
import 'dialect.dart';

/// Best-effort application-log filtering, separate from recorder capture policy.
class LogRedactor {
  LogRedactor(Iterable<String> secrets)
    : _secrets = {
        for (final secret in secrets.where((s) => s.isNotEmpty)) ...[
          secret,
          Uri.encodeComponent(secret),
          Uri.encodeQueryComponent(secret),
          jsonEncode(secret).substring(1, jsonEncode(secret).length - 1),
        ],
      }.toList()..sort((a, b) => b.length.compareTo(a.length));

  factory LogRedactor.fromConfig(
    ProjectConfig config, {
    Iterable<String> secrets = const [],
  }) {
    final values = <String>[...secrets];
    void collect(Map<String, dynamic> entries) {
      for (final entry in entries.entries) {
        if (_credential.hasMatch(entry.key) && entry.value != null) {
          values.add(entry.value.toString());
        }
      }
    }

    collect(Platform.environment);
    for (final path in config.defines) {
      final file = File(inside(config.appRoot, path));
      try {
        final content = file.readAsStringSync();
        if (content.trimLeft().startsWith('{')) {
          collect(stringMap(jsonDecode(content), 'dart defines'));
        } else {
          final entries = <String, String>{};
          for (final line in const LineSplitter().convert(content)) {
            final text = line.trim();
            if (text.isEmpty || text.startsWith('#')) continue;
            final match = RegExp(
              r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$',
            ).firstMatch(text);
            if (match == null || match[2]!.startsWith('"""')) {
              throw const FormatException();
            }
            final raw = match[2]!;
            String? value;
            for (final quote in ['"', "'", '`']) {
              value ??= RegExp(
                '^$quote(.*)$quote\\s*(?:#.*)?\$',
              ).firstMatch(raw)?[1];
            }
            value ??= RegExp(r'^([^#\n\s]*)\s*(?:#.*)?$').firstMatch(raw)?[1];
            entries[match[1]!] = value ?? raw;
          }
          collect(entries);
        }
      } catch (_) {
        throw GherkinException(
          'Cannot read dart-define file for log redaction (contents suppressed)',
        );
      }
    }
    return LogRedactor(values);
  }

  final List<String> _secrets;
  static final _credential = RegExp(
    r'key|token|secret|password|passwd|credential|authorization|signature|session|cookie',
    caseSensitive: false,
  );
  static final _query = RegExp(r'''([?&])([^\s=&#"'<>]+)=([^\s&#"'<>]*)''');
  static final _authorization = RegExp(
    r'''(\b(?:authorization|proxy-authorization)\s*[:=]\s*["']?)(?:Bearer|Basic)\s+[^\s,"'\}\]]+''',
    caseSensitive: false,
  );

  String redact(String text) {
    // Preserve JSON types and escaping, especially recorder seq/sensitive fields.
    final marker = text.indexOf('[GHERKIN_REC] ');
    final start = marker < 0 ? 0 : marker + 14;
    try {
      final value = jsonDecode(text.substring(start));
      if (value is Map || value is List) {
        return '${_redactText(text.substring(0, start))}${jsonEncode(_redactJson(value))}';
      }
    } catch (_) {
      // Ordinary logs are unstructured; malformed events still fail conversion.
    }
    return _redactText(text);
  }

  Object? _redactJson(Object? value) => switch (value) {
    String() => isPlaceholder(value) ? value : _redactText(value),
    List() => value.map(_redactJson).toList(),
    Map() => value.map(
      (key, value) => MapEntry(
        key,
        [
              'authorization',
              'proxy-authorization',
            ].contains(key.toString().toLowerCase())
            ? '[REDACTED]'
            : _redactJson(value),
      ),
    ),
    _ => value,
  };

  String _redactText(String text) {
    var result = text;
    for (final secret in _secrets) {
      result = result.replaceAll(secret, '[REDACTED]');
    }
    result = result.replaceAllMapped(_query, (m) {
      String key;
      try {
        key = Uri.decodeComponent(m[2]!);
      } catch (_) {
        key = m[2]!;
      }
      return _credential.hasMatch(key) || key.toLowerCase() == 'code'
          ? '${m[1]}${m[2]}=[REDACTED]'
          : m[0]!;
    });
    return result.replaceAllMapped(_authorization, (m) => '${m[1]}[REDACTED]');
  }
}
