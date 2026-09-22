import 'dart:convert';

class GherkinException implements Exception {
  final String message;
  GherkinException(this.message);
  @override
  String toString() => message;
}

enum Support { both, marionette, patrol, manual }

class Step {
  final String kind;
  final List<String> args;
  final int line;
  final String source;
  final Support support;
  Step(
    this.kind,
    this.args,
    this.line,
    this.source, [
    this.support = Support.both,
  ]);
  bool get assertion => kind.startsWith('assert_');
  Map<String, Object> toJson() => {
    'kind': kind,
    'args': args,
    'line': line,
    'support': support.name,
  };
}

class Scenario {
  final String name;
  final List<String> tags;
  final List<Step> steps = [];
  Scenario(this.name, this.tags);
}

class Feature {
  final String name;
  final String path;
  final List<String> tags;
  final List<Step> background = [];
  final List<Scenario> scenarios = [];
  Feature(this.name, this.path, this.tags);
  Iterable<Step> get allSteps => [
    ...background,
    ...scenarios.expand((s) => s.steps),
  ];
}

const quoted = r'"((?:[^"\\]|\\["\\nrt])*)"';
String decodeArgument(String value) => jsonDecode('"$value"') as String;
bool isPlaceholder(String s) =>
    RegExp(r'^\$\{(?:env|fixture):[A-Za-z_][A-Za-z0-9_.-]*\}$').hasMatch(s);
bool sensitiveKey(String s) => RegExp(
  r'password|passwd|secret|otp|one.?time|verification.?code|card|cvv|cvc|pin|token',
  caseSensitive: false,
).hasMatch(s);

Step parseStep(String text, int line) {
  Step? match(
    String pattern,
    String kind, {
    Support support = Support.both,
    bool decode = true,
  }) {
    final m = RegExp('^$pattern\$').firstMatch(text);
    if (m == null) return null;
    return Step(
      kind,
      [
        for (var i = 1; i <= m.groupCount; i++)
          decode ? decodeArgument(m[i]!) : m[i]!,
      ],
      line,
      text,
      support,
    );
  }

  if (text == 'the app is running in the integration environment') {
    return Step('environment', [], line, text);
  }
  if (text == 'I am logged out') {
    return Step('fixture', ['logged_out'], line, text);
  }
  final action =
      match('I tap the widget keyed $quoted', 'tap_key') ??
      match('I tap the exact text $quoted', 'tap_text') ??
      match('I enter $quoted into the widget keyed $quoted', 'enter') ??
      match('I scroll to the widget keyed $quoted', 'scroll_key') ??
      match('I scroll to the exact text $quoted', 'scroll_text') ??
      match('I select the fixture $quoted', 'fixture') ??
      match('I use actor $quoted', 'actor', support: Support.marionette) ??
      match(
        'I tap the native notification with text $quoted',
        'notification',
        support: Support.patrol,
      ) ??
      match(
        'I select the system photo $quoted',
        'photo',
        support: Support.manual,
      );
  if (action != null) {
    if (action.args.any((a) => a.isEmpty) && action.kind != 'enter') {
      throw GherkinException('line $line: empty selector');
    }
    if (action.kind == 'enter' &&
        (action.args[1].isEmpty ||
            (sensitiveKey(action.args[1]) && !isPlaceholder(action.args[0])))) {
      throw GherkinException(
        'line $line: sensitive fields require a fixture/env placeholder and a non-empty key',
      );
    }
    return action;
  }
  final wait = match(r'I wait (\d+) milliseconds', 'wait', decode: false);
  if (wait != null) {
    if (int.parse(wait.args[0]) > 30000) {
      throw GherkinException('line $line: wait must be 0..30000 milliseconds');
    }
    return wait;
  }
  for (final target in ['key', 'text']) {
    final prefix = target == 'key' ? 'the widget keyed' : 'the exact text';
    for (final state in ['visible', 'absent']) {
      final step = match(
        '$prefix $quoted is $state',
        'assert_${target}_$state',
      );
      if (step != null) {
        if (step.args.first.isEmpty) {
          throw GherkinException('line $line: empty assertion selector');
        }
        return step;
      }
    }
    final m = RegExp(
      '^$prefix $quoted appears exactly (\\d+) times\$',
    ).firstMatch(text);
    if (m != null) {
      return Step(
        'assert_${target}_count',
        [decodeArgument(m[1]!), m[2]!],
        line,
        text,
      );
    }
  }
  const native = {
    'I grant the permission dialog if visible': 'grant',
    'I deny the permission dialog if visible': 'deny',
    'I press the device home button': 'home',
    'I open notifications': 'notifications',
  };
  if (native.containsKey(text)) {
    return Step(native[text]!, [], line, text, Support.patrol);
  }
  throw GherkinException(
    'line $line: unsupported or malformed step; see references/dialect.md',
  );
}

Feature parseFeature(String source, {String path = '<feature>'}) {
  Feature? feature;
  Scenario? scenario;
  var inBackground = false;
  var sawBackground = false;
  var previousKeyword = '';
  var tags = <String>[];
  final lines = const LineSplitter().convert(source);
  Never fail(int n, String msg) => throw GherkinException('$path:$n: $msg');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    final n = i + 1;
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('@')) {
      final t = line.split(RegExp(r'\s+'));
      if (t.any((v) => !RegExp(r'^@[A-Za-z0-9_-]+$').hasMatch(v))) {
        fail(n, 'malformed tags');
      }
      tags.addAll(t.map((v) => v.substring(1)));
      continue;
    }
    if (line.startsWith('Feature:')) {
      if (feature != null || line.substring(8).trim().isEmpty) {
        fail(n, 'expected exactly one named Feature');
      }
      feature = Feature(line.substring(8).trim(), path, [...tags]);
      tags.clear();
      continue;
    }
    if (feature == null) fail(n, 'Feature must precede scenarios');
    if (line == 'Background:') {
      if (sawBackground || scenario != null || tags.isNotEmpty) {
        fail(n, 'one untagged Background is allowed before scenarios');
      }
      sawBackground = inBackground = true;
      previousKeyword = '';
      continue;
    }
    if (line.startsWith('Scenario:')) {
      final name = line.substring(9).trim();
      if (name.isEmpty || feature.scenarios.any((s) => s.name == name)) {
        fail(n, 'scenario name must be non-empty and unique');
      }
      scenario = Scenario(name, <String>{...feature.tags, ...tags}.toList());
      tags.clear();
      feature.scenarios.add(scenario);
      inBackground = false;
      previousKeyword = '';
      continue;
    }
    final m = RegExp(r'^(Given|When|Then|And|But) (.+)$').firstMatch(line);
    if (m == null || (!inBackground && scenario == null) || tags.isNotEmpty) {
      fail(
        n,
        'expected a supported step or Scenario; outlines, tables and free prose are unsupported',
      );
    }
    if (['And', 'But'].contains(m[1]) && previousKeyword.isEmpty) {
      fail(n, 'And/But needs a preceding Given/When/Then');
    }
    if (!['And', 'But'].contains(m[1])) previousKeyword = m[1]!;
    final step = parseStep(m[2]!, n);
    if (previousKeyword == 'Then' && !step.assertion) {
      fail(n, 'Then must contain an explicit assertion');
    }
    if (step.assertion && previousKeyword != 'Then') {
      fail(n, 'assertions require Then (or following And/But)');
    }
    (inBackground ? feature.background : scenario!.steps).add(step);
  }
  if (feature == null || feature.scenarios.isEmpty || tags.isNotEmpty) {
    fail(
      lines.length,
      'expected Feature with at least one Scenario; no dangling tags',
    );
  }
  if (sawBackground && feature.background.isEmpty) {
    fail(lines.length, 'empty Background');
  }
  if (feature.scenarios.any((s) => s.steps.isEmpty)) {
    fail(lines.length, 'empty Scenario');
  }
  return feature;
}

void validateSupport(Feature f, String backend) {
  for (final s in f.allSteps) {
    if (s.support == Support.manual ||
        (backend == 'patrol' && s.support == Support.marionette) ||
        (backend == 'marionette' && s.support == Support.patrol)) {
      throw GherkinException(
        '${f.path}:${s.line}: ${s.kind} unsupported by $backend (${s.support.name})',
      );
    }
  }
  if (f.tags.contains('draft') ||
      f.scenarios.any((s) => s.tags.contains('draft'))) {
    throw GherkinException(
      '${f.path}: draft recording requires confirmed assertions and resolution of gaps',
    );
  }
}
