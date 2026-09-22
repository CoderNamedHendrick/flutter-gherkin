import 'dart:convert';
import 'dialect.dart';

class Recording {
  final String feature;
  final List<Map<String, dynamic>> gaps;
  final int events;
  Recording(this.feature, this.gaps, this.events);
}

Recording convertRecording(
  String log,
  String name, {
  Set<String> publicKeys = const {},
  Set<String> sensitiveKeys = const {},
}) {
  if (!RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(name)) {
    throw GherkinException('flow name must be a lowercase slug');
  }
  final events = <Map<String, dynamic>>[];
  var row = 0;
  for (final line in const LineSplitter().convert(log)) {
    row++;
    final index = line.indexOf('[GHERKIN_REC] ');
    if (index < 0) continue;
    try {
      final event = Map<String, dynamic>.from(
        jsonDecode(line.substring(index + 14)) as Map,
      );
      if (event['seq'] is! int ||
          event['action'] is! String ||
          event['session'] is! String) {
        throw const FormatException();
      }
      if ((event['seq'] as int) < 0 ||
          !RegExp(r'^[a-z_]+$').hasMatch(event['action'] as String)) {
        throw const FormatException();
      }
      for (final key in [
        'actor',
        'key',
        'text',
        'value',
        'id',
        'type',
        'route',
      ]) {
        if (event[key] != null && event[key] is! String) {
          throw const FormatException();
        }
      }
      for (final key in ['sensitive', 'publicText']) {
        if (event[key] != null && event[key] is! bool) {
          throw const FormatException();
        }
      }
      events.add(event);
    } catch (_) {
      throw GherkinException(
        'Malformed recording event on log line $row (content suppressed)',
      );
    }
  }
  if (events.isEmpty) throw GherkinException('No recording events found');
  if (events.map((e) => e['session']).toSet().length != 1 ||
      events.map((e) => e['actor'] ?? 'default').toSet().length != 1) {
    throw GherkinException(
      'Use one actor/session per conversion; multi-device interleaving needs an explicit user-confirmed segment manifest',
    );
  }
  events.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
  if (events.map((e) => e['seq']).toSet().length != events.length) {
    throw GherkinException(
      'Duplicate sequence numbers: recording may combine sessions',
    );
  }
  final collapsed = <Map<String, dynamic>>[];
  for (final e in events) {
    if (e['action'] == 'nav') continue; // Context only, never an assertion.
    if (collapsed.isNotEmpty &&
        e['action'] == 'enter_text' &&
        collapsed.last['action'] == 'enter_text' &&
        e['key'] == collapsed.last['key']) {
      collapsed.removeLast();
    }
    if (collapsed.isNotEmpty &&
        e['action'] == 'fixture' &&
        collapsed.last['action'] == 'fixture' &&
        e['id'] == collapsed.last['id'] &&
        e['interaction'] != null &&
        e['interaction'] == collapsed.last['interaction']) {
      continue;
    }
    collapsed.add(e);
  }
  final out = StringBuffer(
    '@draft\nFeature: $name\n\n  Scenario: Recorded $name\n    Given the app is running in the integration environment\n',
  );
  final gaps = <Map<String, dynamic>>[];
  String q(dynamic s) => jsonEncode(s.toString());
  for (final e in collapsed) {
    final key = e['key'] as String?;
    final text = e['text'] as String?;
    String? body;
    if (e['action'] == 'tap' || e['action'] == 'scroll_to') {
      final verb = e['action'] == 'tap' ? 'tap' : 'scroll to';
      if (key != null && key.isNotEmpty) {
        body = 'I $verb the widget keyed ${q(key)}';
      } else if (text != null && text.isNotEmpty && e['publicText'] == true) {
        body = 'I $verb the exact text ${q(text)}';
      }
    } else if (e['action'] == 'enter_text' && key != null && key.isNotEmpty) {
      final raw = e['value'] as String? ?? '';
      final safe =
          isPlaceholder(raw) ||
          (publicKeys.contains(key) &&
              !sensitiveKeys.contains(key) &&
              !sensitiveKey(key) &&
              e['sensitive'] != true);
      final value = safe
          ? raw
          : '\${fixture:${key.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}}';
      body = 'I enter ${q(value)} into the widget keyed ${q(key)}';
    } else if (e['action'] == 'fixture' && e['id'] is String) {
      body = 'I select the fixture ${q(e['id'])}';
    }
    if (key == null &&
            ['tap', 'enter_text', 'scroll_to'].contains(e['action']) ||
        body == null) {
      // Never copy values, text, or route parameters into gap diagnostics.
      gaps.add({
        'seq': e['seq'],
        'action': e['action'],
        'type': e['type'],
        'suggested_key':
            '${name.replaceAll('-', '_')}_control_${gaps.length + 1}',
      });
    }
    if (body != null) {
      parseStep(body, 0);
      out.writeln('    When $body');
    } else {
      out.writeln(
        '    # Unresolved ${e['action']} at sequence ${e['seq']}; user review required.',
      );
    }
  }
  out.writeln(
    '    # Confirm meaningful Then assertions, resolve gaps, then remove @draft.',
  );
  parseFeature(out.toString());
  return Recording(out.toString(), gaps, events.length);
}

/// Interleaves only explicitly confirmed actor/sequence segments. Never sorts clocks.
Recording stitchRecordings(
  List<Map<String, dynamic>> segments,
  Map<String, String> logs,
  String name, {
  Set<String> publicKeys = const {},
  Set<String> sensitiveKeys = const {},
}) {
  if (!RegExp(r'^[a-z][a-z0-9_-]*$').hasMatch(name) || segments.isEmpty) {
    throw GherkinException(
      'A slug and non-empty explicit segment manifest are required',
    );
  }
  final out = StringBuffer(
    '@draft\nFeature: $name\n\n  Scenario: Recorded $name\n    Given the app is running in the integration environment\n',
  );
  final used = <String>{};
  final gaps = <Map<String, dynamic>>[];
  var count = 0;
  for (final segment in segments) {
    final actor = segment['actor'];
    final session = segment['session'];
    final start = segment['start_seq'];
    final end = segment['end_seq'];
    if (actor is! String ||
        session is! String ||
        start is! int ||
        end is! int ||
        end < start ||
        !logs.containsKey(actor)) {
      throw GherkinException(
        'Each segment needs actor, session, start_seq and end_seq, with a matching log',
      );
    }
    final selected = <String>[];
    for (final line in const LineSplitter().convert(logs[actor]!)) {
      final i = line.indexOf('[GHERKIN_REC] ');
      if (i < 0) continue;
      Map<String, dynamic> event;
      try {
        event = Map<String, dynamic>.from(
          jsonDecode(line.substring(i + 14)) as Map,
        );
      } catch (_) {
        throw GherkinException(
          'Malformed multi-device event (content suppressed)',
        );
      }
      if (event['session'] != session) continue;
      final seq = event['seq'];
      if (seq is! int) {
        throw GherkinException('Event sequence must be an integer');
      }
      if (seq < start || seq > end) continue;
      if (event['actor'] != actor) {
        throw GherkinException('Actor does not match recording segment');
      }
      if (!used.add('$actor/$session/$seq')) {
        throw GherkinException(
          'Overlapping recording segments or duplicate events',
        );
      }
      selected.add('[GHERKIN_REC] ${jsonEncode(event)}');
    }
    if (selected.isEmpty) {
      throw GherkinException('Recording segment contains no events');
    }
    final converted = convertRecording(
      selected.join('\n'),
      name,
      publicKeys: publicKeys,
      sensitiveKeys: sensitiveKeys,
    );
    out.writeln('    When I use actor ${jsonEncode(actor)}');
    for (final line in const LineSplitter().convert(converted.feature)) {
      if (line.startsWith('    When ') || line.startsWith('    # Unresolved')) {
        out.writeln(line);
      }
    }
    count += converted.events;
    gaps.addAll(converted.gaps.map((gap) => {'actor': actor, ...gap}));
  }
  out.writeln(
    '    # Confirm assertions and resolve gaps before removing @draft.',
  );
  parseFeature(out.toString());
  return Recording(out.toString(), gaps, count);
}
