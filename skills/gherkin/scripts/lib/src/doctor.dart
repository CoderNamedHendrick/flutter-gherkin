import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'config.dart';
import 'install.dart';

String? executablePath(String name) {
  if (p.isAbsolute(name)) return File(name).existsSync() ? name : null;
  for (final dir in (Platform.environment['PATH'] ?? '').split(
    Platform.isWindows ? ';' : ':',
  )) {
    for (final suffix
        in Platform.isWindows ? ['.exe', '.bat', '.cmd', ''] : ['']) {
      final f = File(p.join(dir, '$name$suffix'));
      if (f.existsSync()) return f.path;
    }
  }
  return null;
}

Future<List<Map<String, String>>> doctor(
  String root, {
  bool probe = false,
}) async {
  final rows = <Map<String, String>>[];
  void add(String check, bool ok, String detail, {bool required = true}) =>
      rows.add({
        'check': check,
        'status': ok
            ? 'PASS'
            : required
            ? 'FAIL — required'
            : 'WARN — optional or selected-mode only',
        'detail': detail,
      });
  add('Dart', true, Platform.version.split('\n').first);
  ProjectConfig? c;
  try {
    c = ProjectConfig.load(root);
    add('config', true, 'Valid schema');
  } catch (e) {
    add('config', false, e.toString());
  }
  final missingDirectories =
      [
            'features',
            'fixtures',
            'evidence/screenshots',
            'evidence/logs',
            'support',
          ]
          .where(
            (name) => !Directory(p.join(root, 'gherkin', name)).existsSync(),
          )
          .toList();
  add(
    'Gherkin directories',
    missingDirectories.isEmpty,
    missingDirectories.isEmpty
        ? 'Standard project layout present'
        : 'Missing: ${missingDirectories.join(', ')}',
  );
  final apps = findApps(root);
  final app = c?.appRoot ?? (apps.length == 1 ? apps.single : null);
  add(
    'Flutter project root',
    app != null,
    app ?? 'Choose one app: ${apps.join(', ')}',
  );
  final flutter =
      c?.flutter ?? (app == null ? ['flutter'] : detectFlutter(app));
  add('Flutter tool', executablePath(flutter.first) != null, flutter.join(' '));
  for (final name in ['marionette', 'marionette_mcp', 'patrol']) {
    add(
      '$name executable',
      executablePath(name) != null,
      executablePath(name) ?? 'Not on PATH',
      required:
          name == 'marionette' && executablePath('marionette_mcp') == null,
    );
  }
  if (app == null) return rows;
  final pub =
      loadYaml(File(p.join(app, 'pubspec.yaml')).readAsStringSync()) as Map;
  final deps = {
    ...?pub['dependencies'] as Map?,
    ...?pub['dev_dependencies'] as Map?,
  };
  final patrol = c?.patrol['enabled'] == true;
  add(
    'Patrol test directory',
    Directory(p.join(app, 'integration_test')).existsSync(),
    'Expected integration_test/ in the Flutter app root',
    required: patrol,
  );
  final patrolCommand = List<String>.from(c?.patrol['command'] ?? ['patrol']);
  add(
    'Selected Patrol command',
    executablePath(patrolCommand.first) != null,
    patrolCommand.join(' '),
    required: patrol,
  );
  for (final name in ['marionette_flutter', 'patrol', 'patrol_mcp']) {
    add(
      '$name dependency',
      deps.containsKey(name),
      deps[name]?.toString() ?? 'Missing',
      required: name == 'marionette_flutter' || patrol,
    );
  }
  final lock = File(p.join(app, 'pubspec.lock'));
  add(
    'Pub resolved',
    lock.existsSync() &&
        File(p.join(app, '.dart_tool/package_config.json')).existsSync(),
    'pubspec.lock + .dart_tool/package_config.json',
  );
  final info = inspectApp(app);
  final sites = info['binding_sites'] as List;
  add(
    'Binding integration',
    false,
    'Inspect entrypoint order and test isolation; candidates: ${sites.join(', ')}',
    required: false,
  );
  final entry = File(p.join(app, c?.entrypoint ?? 'lib/main.dart'));
  final text = entry.existsSync() ? entry.readAsStringSync() : '';
  add(
    'Binding call present',
    text.contains('initializeGherkinBinding') ||
        text.contains('MarionetteBinding.ensureInitialized'),
    'Static presence only; live smoke required',
  );
  add(
    'Recording harness',
    text.contains('GherkinRecordingHarness'),
    'App root must mount recorder in debug record runs',
  );
  add(
    'Patrol configuration',
    (pub['patrol'] as Map?)?['test_directory'] == 'integration_test',
    'Expected patrol.test_directory: integration_test',
    required: patrol,
  );
  for (final platform in ['android', 'ios']) {
    final selected =
        patrol && (c?.data['platforms'] as List? ?? []).contains(platform);
    final files = Directory(p.join(app, platform));
    var native = '';
    if (files.existsSync()) {
      for (final file
          in files
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .where(
                (f) =>
                    RegExp(
                      r'\.(kts|gradle|java|m|swift|pbxproj)$',
                    ).hasMatch(f.path) &&
                    !f.path.contains('/Pods/') &&
                    !f.path.contains('/build/'),
              )) {
        native += file.readAsStringSync();
      }
    }
    final configured = platform == 'android'
        ? native.contains('PatrolJUnitRunner') &&
              native.contains('ANDROIDX_TEST_ORCHESTRATOR') &&
              native.contains('androidx.test:orchestrator')
        : native.contains('PATROL_INTEGRATION_TEST_IOS_RUNNER');
    add(
      'Patrol $platform native markers',
      configured,
      'Static heuristic; verify target membership, scheme, IDs and device run',
      required: selected,
    );
  }
  final agent = c?.data['agent'] as Map?;
  final configPath = agent?['config_path'];
  if (configPath is String) {
    final f = File(inside(root, configPath));
    final body = f.existsSync() ? f.readAsStringSync() : '';
    add(
      'Marionette MCP registration',
      body.contains('marionette'),
      'Selected host ${agent?['name']}; loaded tools must be checked by agent',
      required: false,
    );
    add(
      'Patrol MCP registration',
      body.contains('patrol'),
      'Selected host ${agent?['name']}; loaded tools must be checked by agent',
      required: false,
    );
  } else {
    add(
      'MCP registration',
      false,
      'Host/config not selected; CLI can be used',
      required: false,
    );
  }
  final packages = lock.existsSync()
      ? (loadYaml(lock.readAsStringSync()) as Map)['packages'] as Map?
      : null;
  final patrolVersion = packages?['patrol']?['version']?.toString();
  final cliVersion = packages?['patrol_cli']?['version']?.toString();
  final compatible = patrolCompatibility(cliVersion, patrolVersion);
  add(
    'Resolved Patrol compatibility',
    compatible == true,
    'patrol=$patrolVersion, project patrol_cli=$cliVersion; verified table 2026-09-21. Recheck current upstream at installation.',
    required: patrol && compatible == false,
  );
  add(
    'Marionette compatibility',
    false,
    'Resolved package/API version must match bridge; prove with non-empty live tree',
    required: false,
  );
  add(
    'Smoke-test readiness',
    false,
    'Needs selected device, allowed environment, bootstrap inspection and non-empty live tree',
    required: false,
  );
  if (probe) {
    for (final command in [
      [...flutter, 'devices', '--machine'],
      [...flutter, 'emulators'],
      if (patrol && executablePath(patrolCommand.first) != null)
        [...patrolCommand, 'doctor'],
    ]) {
      try {
        final result = await Process.run(
          command.first,
          command.skip(1).toList(),
          workingDirectory: app,
        ).timeout(const Duration(seconds: 45));
        final output = result.stdout.toString();
        if (command.last == 'doctor') {
          final active = RegExp(
            r'Patrol CLI version: (\d+\.\d+\.\d+)',
          ).firstMatch(output)?[1];
          final match = patrolCompatibility(active, patrolVersion);
          add(
            'Active Patrol CLI compatibility',
            match == true,
            'Selected CLI=$active, app patrol=$patrolVersion; project-resolved CLI may differ',
            required: patrol && match == false,
          );
        }

        add(
          command.join(' '),
          result.exitCode == 0,
          output.length > 6000 ? output.substring(0, 6000) : output,
          required: command.last == 'doctor' && patrol,
        );
      } catch (_) {
        add(
          command.join(' '),
          false,
          'Probe unavailable or timed out',
          required: false,
        );
      }
    }
  } else {
    add(
      'Device / patrol doctor probes',
      false,
      'Run doctor --probe (external SDK commands may write their own caches)',
      required: false,
    );
  }
  return rows;
}

String doctorJson(List<Map<String, String>> rows) =>
    const JsonEncoder.withIndent('  ').convert({
      'checks': rows,
      'ok': !rows.any((r) => r['status']!.startsWith('FAIL')),
    });

// Conservative known ranges from upstream compatibility table (2026-09-21).
// Unknown major/minor families require fresh upstream verification, never a guessed PASS.
bool? patrolCompatibility(String? cli, String? package) {
  List<int>? parse(String? value) {
    if (value == null || !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
      return null;
    }
    return value.split('.').map(int.parse).toList();
  }

  final c = parse(cli);
  final p = parse(package);
  if (c == null || p == null) return null;
  int compare(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      final delta = a[i].compareTo(b[i]);
      if (delta != 0) return delta;
    }
    return 0;
  }

  bool range(List<int> value, List<int> min, List<int> max) =>
      compare(value, min) >= 0 && compare(value, max) <= 0;
  if (c[0] == 4 && c[1] >= 7 && c[1] <= 8) {
    if (p[0] > 4) return null;
    return p[0] == 4 && p[1] >= 9;
  }
  if (range(c, [4, 5, 0], [4, 6, 1])) return range(p, [4, 7, 0], [4, 8, 0]);
  if (range(c, [4, 4, 0], [4, 4, 0])) return range(p, [4, 6, 0], [4, 6, 1]);
  if (range(c, [4, 3, 0], [4, 3, 1])) return range(p, [4, 5, 0], [4, 5, 0]);
  if (range(c, [4, 2, 0], [4, 2, 0])) return range(p, [4, 2, 0], [4, 4, 0]);
  if (range(c, [3, 9, 0], [3, 10, 0])) return range(p, [3, 18, 0], [3, 19, 0]);

  return null;
}
