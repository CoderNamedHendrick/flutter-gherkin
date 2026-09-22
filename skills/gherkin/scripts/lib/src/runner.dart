import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'config.dart';
import 'dialect.dart';

abstract class Driver {
  Future<void> action(Step step);
  Future<List<Map<String, dynamic>>> elements();
  Future<void> screenshot(String path);
  Future<String> logs();
}

class CliDriver implements Driver {
  final String uri;
  final String executable;
  CliDriver(this.uri, {this.executable = 'marionette'});
  Future<String> invoke(List<String> args) async {
    final process = await Process.start(executable, ['--uri', uri, ...args]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    final code = await process.exitCode.timeout(
      const Duration(seconds: 40),
      onTimeout: () {
        process.kill();
        return 124;
      },
    );
    await errors;
    if (code != 0) {
      throw GherkinException(
        'Marionette ${args.first} failed (exit $code; values suppressed)',
      );
    }
    return output;
  }

  @override
  Future<void> action(Step s) async {
    final args = s.kind == 'enter'
        ? ['enter-text', '--key', s.args[1], '--input', s.args[0]]
        : [
            s.kind.startsWith('tap') ? 'tap' : 'scroll-to',
            s.kind.endsWith('key') ? '--key' : '--text',
            s.args[0],
          ];
    await invoke(args);
  }

  @override
  Future<List<Map<String, dynamic>>> elements() async =>
      parseCliElements(await invoke(['get-interactive-elements']));
  @override
  Future<void> screenshot(String path) async {
    await invoke(['take-screenshots', '--output', path]);
  }

  @override
  Future<String> logs() => invoke(['get-logs']);
}

List<Map<String, dynamic>> parseCliElements(String text) {
  final count = RegExp(
    r'Found (\d+) interactive element\(s\):',
  ).firstMatch(text);
  if (count == null) {
    throw GherkinException(
      'Unknown Marionette CLI tree format; use advertised MCP tools',
    );
  }
  final rows = text.split('\n').where((s) => s.startsWith('Type: ')).toList();
  if (rows.length != int.parse(count[1]!)) {
    throw GherkinException(
      'Ambiguous/multiline CLI tree; inspect through MCP; reject counts if its output is also ambiguous',
    );
  }
  return rows.map((row) {
    final head = RegExp(
      r'^Type: [^,\r\n]+(?:, Key: "([^"\r\n]*)")?(?:, Text: "([^"\r\n]*)")?(?=, |$)',
    ).firstMatch(row);
    final visible = RegExp(r', visible: (true|false)$').firstMatch(row);
    if (head == null ||
        visible == null ||
        RegExp(r'^, (Key|Text):').hasMatch(row.substring(head.end))) {
      throw GherkinException('Ambiguous CLI selectors/visibility; use MCP');
    }
    final result = <String, dynamic>{
      if (head[1] != null) 'key': head[1],
      if (head[2] != null) 'text': head[2],
      'visible': visible[1] == 'true',
    };
    return result;
  }).toList();
}

String resolveValue(String value) {
  if (!isPlaceholder(value)) return value;
  final label = value.substring(2, value.length - 1).split(':');
  final variable = label[0] == 'env'
      ? label[1]
      : 'GHERKIN_FIXTURE_${label[1].toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_')}';
  final resolved = Platform.environment[variable];
  if (resolved == null) {
    throw GherkinException(
      'Missing environment reference $variable (value suppressed)',
    );
  }
  return resolved;
}

bool assertionMatches(Step s, List<Map<String, dynamic>> tree) {
  final parts = s.kind.split('_');
  final matches = tree
      .where((e) => e[parts[1]] == s.args[0] && e['visible'] != false)
      .length;
  return switch (parts[2]) {
    'visible' => matches > 0,
    'absent' => matches == 0,
    'count' => matches == int.parse(s.args[1]),
    _ => false,
  };
}

Future<Map<String, dynamic>> runSuite(
  ProjectConfig c,
  List<Feature> features,
  Map<String, Driver> drivers, {
  bool confirmProduction = false,
  Duration assertionTimeout = const Duration(seconds: 5),
}) async {
  c.guard(confirmProduction: confirmProduction);
  if ((Set<Driver>.identity()..addAll(drivers.values)).length !=
      drivers.length) {
    throw GherkinException(
      'Actors require dedicated driver connections; shared driver instance rejected',
    );
  }

  for (final f in features) {
    validateSupport(f, 'marionette');
    for (final s in f.allSteps) {
      for (final expanded in c.expand(s)) {
        if (expanded.kind == 'enter') resolveValue(expanded.args[0]);
      }
      if (s.kind == 'actor' &&
          (!drivers.containsKey(s.args[0]) ||
              !c.actors.containsKey(s.args[0]))) {
        throw GherkinException(
          'Actor ${s.args[0]} requires a configured dedicated connection',
        );
      }
    }
  }
  final keys = keyManifest(c.appRoot);
  final evidence = Directory(
    inside(
      c.root,
      'gherkin/evidence/run-${DateTime.now().microsecondsSinceEpoch}',
    ),
  )..createSync(recursive: true);
  final results = <Map<String, dynamic>>[];
  var checkpoint = 0;
  for (final f in features) {
    for (final scenario in f.scenarios) {
      var actor = drivers.containsKey('default') ? 'default' : '';
      final steps = <Map<String, dynamic>>[];
      var passed = true;
      for (final original in [...f.background, ...scenario.steps]) {
        for (final s in c.expand(original)) {
          final result = <String, dynamic>{
            'line': s.line,
            'kind': s.kind,
            'actor': actor,
          };
          Driver? driver;
          try {
            if (s.kind == 'actor') {
              actor = s.args[0];
              result['actor'] = actor;
            } else if (s.kind != 'environment') {
              driver = drivers[actor];
              if (driver == null) {
                throw GherkinException('Select an actor before device actions');
              }
              if (s.kind == 'wait') {
                await Future<void>.delayed(
                  Duration(milliseconds: int.parse(s.args[0])),
                );
              } else if (s.assertion) {
                final deadline = DateTime.now().add(assertionTimeout);
                while (!assertionMatches(s, await driver.elements())) {
                  if (DateTime.now().isAfter(deadline)) {
                    throw GherkinException('Assertion ${s.kind} failed');
                  }
                  await Future<void>.delayed(const Duration(milliseconds: 100));
                }
                final screenshot = p.join(
                  evidence.path,
                  'checkpoint-${checkpoint++}.png',
                );
                try {
                  await driver.screenshot(screenshot);
                  result['screenshot'] = screenshot;
                } catch (_) {
                  result['evidence_warning'] = 'Screenshot unavailable';
                }
              } else {
                // Exact text actions must resolve uniquely; known keys avoid tree scans.
                if (s.kind == 'tap_text') {
                  final count = (await driver.elements())
                      .where(
                        (e) => e['text'] == s.args[0] && e['visible'] != false,
                      )
                      .length;
                  if (count != 1) {
                    throw GherkinException(
                      'Exact text action is missing or ambiguous ($count matches)',
                    );
                  }
                }
                await driver.action(
                  s.kind == 'enter'
                      ? Step(
                          s.kind,
                          [resolveValue(s.args[0]), s.args[1]],
                          s.line,
                          s.source,
                        )
                      : s,
                );
              }
            }
            result['status'] = 'PASS';
          } catch (e) {
            passed = false;
            result['status'] = 'FAIL';
            result['error'] = e is GherkinException
                ? e.message
                : 'Driver failure (details suppressed)';
            if (driver != null) {
              final screenshot = p.join(
                evidence.path,
                'failure-${checkpoint++}.png',
              );
              try {
                await driver.screenshot(screenshot);
                result['screenshot'] = screenshot;
              } catch (_) {
                result['screenshot_warning'] = 'Unavailable';
              }
              try {
                await driver.elements();
              } catch (
                _
              ) {} // recovery observation, never continue past failure
              try {
                var logs = await driver.logs();
                for (final feature in features) {
                  for (final step
                      in feature.allSteps
                          .expand(c.expand)
                          .where(
                            (s) =>
                                s.kind == 'enter' && isPlaceholder(s.args[0]),
                          )) {
                    final secret = resolveValue(step.args[0]);
                    if (secret.isNotEmpty) {
                      logs = logs.replaceAll(secret, '[REDACTED]');
                    }
                  }
                }
                final path = p.join(
                  evidence.path,
                  'failure-${checkpoint++}.log',
                );
                File(path).writeAsStringSync(logs);
                result['log'] = path;
              } catch (_) {
                result['log_warning'] = 'Unavailable';
              }
            }
          }
          steps.add(result);
          if (!passed) break;
        }
        if (!passed) break;
      }
      results.add({
        'feature': p.relative(f.path, from: c.root),
        'scenario': scenario.name,
        'status': passed ? 'PASS' : 'FAIL',
        'steps': steps,
      });
    }
  }
  final report = {
    'passed': results.where((s) => s['status'] == 'PASS').length,
    'failed': results.where((s) => s['status'] == 'FAIL').length,
    'scenarios': results,
    'key_manifest': keys,
  };
  File(
    p.join(evidence.path, 'report.json'),
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  return {...report, 'report': p.join(evidence.path, 'report.json')};
}

List<String> keyManifest(String appRoot) {
  final keys = <String>{};
  final lib = Directory(p.join(appRoot, 'lib'));
  if (!lib.existsSync()) return [];
  final pattern = RegExp(
    r'''ValueKey(?:<String>)?\s*\(\s*['"]([^'"\r\n]+)['"]''',
  );
  for (final file
      in lib.listSync(recursive: true, followLinks: false).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    keys.addAll(pattern.allMatches(file.readAsStringSync()).map((m) => m[1]!));
  }
  return keys.toList()..sort();
}
