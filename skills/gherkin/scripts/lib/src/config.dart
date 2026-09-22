import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'dialect.dart';

Map<String, dynamic> stringMap(dynamic v, String label) {
  if (v is! Map || v.keys.any((k) => k is! String)) {
    throw GherkinException('$label must be a mapping');
  }
  return Map<String, dynamic>.from(v);
}

class ProjectConfig {
  final String root;
  final Map<String, dynamic> data;
  ProjectConfig(this.root, this.data) {
    validate();
  }
  factory ProjectConfig.load(String root) {
    final file = File(p.join(root, 'gherkin/config.yaml'));
    if (!file.existsSync()) {
      throw GherkinException(
        'Missing gherkin/config.yaml; run gherkin install',
      );
    }
    try {
      return ProjectConfig(
        p.normalize(p.absolute(root)),
        stringMap(loadYaml(file.readAsStringSync()), 'config'),
      );
    } on YamlException {
      throw GherkinException(
        'Invalid YAML in gherkin/config.yaml (contents suppressed)',
      );
    }
  }
  String get appRoot => inside(root, data['app_root'] as String);
  String get entrypoint => data['entrypoint'] as String;
  String get environment => data['environment'] as String;
  List<String> get flutter => List<String>.from(data['flutter_command']);
  List<String> get defines =>
      List<String>.from(data['dart_define_files'] ?? []);
  List<String> get suite => List<String>.from(data['suite'] ?? []);
  Map<String, dynamic> get fixtures =>
      stringMap(data['fixtures'] ?? {}, 'fixtures');
  Map<String, dynamic> get actors => stringMap(data['actors'] ?? {}, 'actors');
  Map<String, dynamic> get patrol => stringMap(data['patrol'] ?? {}, 'patrol');
  String get bootstrap =>
      patrol['bootstrap'] as String? ?? 'gherkin/support/patrol_bootstrap.dart';
  void validate() {
    if (data['version'] != 1) {
      throw GherkinException('config.version must be 1');
    }
    const known = {
      'version',
      'app_root',
      'entrypoint',
      'flavor',
      'environment',
      'allowed_environments',
      'production',
      'dart_define_files',
      'default_device',
      'platforms',
      'suite',
      'fixtures',
      'actors',
      'flutter_command',
      'marionette',
      'patrol',
      'agent',
      'sensitive_keys',
      'public_text_keys',
    };
    final unknown = data.keys.where((k) => !known.contains(k));
    if (unknown.isNotEmpty) {
      throw GherkinException('Unknown config keys: ${unknown.join(', ')}');
    }
    for (final k in ['app_root', 'entrypoint', 'environment']) {
      if (data[k] is! String || (data[k] as String).isEmpty) {
        throw GherkinException('$k must be a non-empty string');
      }
    }
    for (final k in ['flutter_command', 'allowed_environments', 'platforms']) {
      if (data[k] is! List ||
          (data[k] as List).isEmpty ||
          (data[k] as List).any((v) => v is! String || v.isEmpty)) {
        throw GherkinException('$k must be a non-empty string list');
      }
    }
    for (final k in [
      'suite',
      'dart_define_files',
      'sensitive_keys',
      'public_text_keys',
    ]) {
      if (data[k] != null &&
          (data[k] is! List || (data[k] as List).any((v) => v is! String))) {
        throw GherkinException('$k must be a string list');
      }
    }
    if (!(data['allowed_environments'] as List).contains(environment)) {
      throw GherkinException('environment is not in allowed_environments');
    }
    if (data['production'] is! bool) {
      throw GherkinException('production must explicitly be true or false');
    }
    if (RegExp(
          r'(^|[-_])prod(uction)?($|[-_])',
          caseSensitive: false,
        ).hasMatch(environment) &&
        data['production'] != true) {
      throw GherkinException(
        'Production-like environment requires production: true',
      );
    }
    for (final k in ['flavor', 'default_device']) {
      if (data[k] != null &&
          (data[k] is! String || (data[k] as String).isEmpty)) {
        throw GherkinException('$k must be null or a non-empty string');
      }
    }
    if ((data['platforms'] as List).any(
      (v) => !['ios', 'android'].contains(v),
    )) {
      throw GherkinException('v1 supported platforms are ios and android');
    }
    if (suite.toSet().length != suite.length) {
      throw GherkinException('suite contains duplicate paths');
    }
    for (final k in ['fixtures', 'actors', 'patrol', 'marionette', 'agent']) {
      if (data[k] != null) stringMap(data[k], k);
    }
    final patrolMap = patrol;
    if (patrolMap['command'] != null &&
        (patrolMap['command'] is! List ||
            (patrolMap['command'] as List).isEmpty ||
            (patrolMap['command'] as List).any(
              (v) => v is! String || v.isEmpty,
            ))) {
      throw GherkinException(
        'patrol.command must be a non-empty command argument list',
      );
    }

    if (patrolMap['enabled'] != null && patrolMap['enabled'] is! bool) {
      throw GherkinException('patrol.enabled must be boolean');
    }
    if (patrolMap['bootstrap'] != null && patrolMap['bootstrap'] is! String) {
      throw GherkinException('patrol.bootstrap must be a relative path string');
    }
    final agentMap = stringMap(data['agent'] ?? {}, 'agent');
    for (final key in ['name', 'config_path']) {
      if (agentMap[key] != null && agentMap[key] is! String) {
        throw GherkinException('agent.$key must be a string or null');
      }
    }
    if (agentMap['config_path'] is String) {
      inside(root, agentMap['config_path'] as String);
    }
    inside(root, data['app_root']);
    inside(appRoot, entrypoint);
    inside(root, bootstrap);
    for (final f in defines) {
      inside(appRoot, f);
    }
    for (final backend in ['marionette', 'patrol']) {
      final pref = (data[backend] as Map?)?['preference'] ?? 'auto';
      if (!['auto', 'mcp', 'cli'].contains(pref)) {
        throw GherkinException('$backend.preference must be auto, mcp or cli');
      }
    }
    for (final e in fixtures.entries) {
      if (e.value is! List || (e.value as List).any((s) => s is! String)) {
        throw GherkinException(
          'fixtures.${e.key} must be a list of dialect step bodies',
        );
      }
      for (final raw in e.value as List) {
        final s = parseStep(raw as String, 0);
        if (['fixture', 'actor', 'environment'].contains(s.kind) ||
            s.support != Support.both) {
          throw GherkinException(
            'fixture adapters must contain concrete portable actions/assertions',
          );
        }
      }
    }
    for (final e in actors.entries) {
      final a = stringMap(e.value, 'actor ${e.key}');
      if (a['device'] is! String ||
          a['connection'] is! String ||
          a['account_env'] is! String ||
          a.values.any((v) => v is String && v.isEmpty)) {
        throw GherkinException(
          'actor ${e.key} needs device, dedicated connection and account_env',
        );
      }
    }
    if (actors.values.map((a) => a['connection']).toSet().length !=
            actors.length ||
        actors.values.map((a) => a['device']).toSet().length != actors.length) {
      throw GherkinException('actors require distinct devices and connections');
    }
  }

  void guard({bool confirmProduction = false}) {
    if (data['production'] == true && !confirmProduction) {
      throw GherkinException(
        'Production requires renewed user confirmation; then pass --confirm-production for this run',
      );
    }
  }

  List<Step> expand(Step s) {
    if (s.kind != 'fixture') return [s];
    final list = fixtures[s.args[0]];
    if (list is! List || list.isEmpty) {
      throw GherkinException(
        'Missing deterministic fixture adapter: ${s.args[0]}',
      );
    }
    return list.map((v) => parseStep(v as String, s.line)).toList();
  }
}

String inside(String root, String relative) {
  final result = p.normalize(p.join(root, relative));
  if (p.isAbsolute(relative) ||
      (!p.isWithin(root, result) && result != p.normalize(root))) {
    throw GherkinException('Path must remain within project: $relative');
  }
  // Reject symlink escapes, including an existing parent of a new output.
  var ancestor = result;
  while (FileSystemEntity.typeSync(ancestor, followLinks: false) ==
      FileSystemEntityType.notFound) {
    ancestor = p.dirname(ancestor);
  }
  final resolved = Directory(ancestor).resolveSymbolicLinksSync();
  final realRoot = Directory(root).resolveSymbolicLinksSync();
  if (resolved != realRoot && !p.isWithin(realRoot, resolved)) {
    throw GherkinException('Symlink escapes project: $relative');
  }
  return result;
}

List<File> resolveFeatures(ProjectConfig c, String target) {
  final base = inside(c.root, 'gherkin/features');
  if (!Directory(base).existsSync()) {
    throw GherkinException('Missing gherkin/features');
  }
  String rel = target;
  if (target == 'gherkin') {
    rel = '';
  } else if (target.startsWith('gherkin/features/')) {
    rel = target.substring('gherkin/features/'.length);
  } else if (p.isAbsolute(target)) {
    rel = p.relative(target, from: base);
  }
  var resolved = inside(base, rel);
  if (!File(resolved).existsSync() &&
      !Directory(resolved).existsSync() &&
      !resolved.endsWith('.feature')) {
    resolved += '.feature';
  }
  final files = File(resolved).existsSync()
      ? [File(resolved)]
      : Directory(resolved).existsSync()
      ? Directory(resolved)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => f.path.endsWith('.feature'))
            .toList()
      : <File>[];
  if (files.isEmpty || files.any((f) => !f.path.endsWith('.feature'))) {
    throw GherkinException('No features found for $target');
  }
  for (final f in files) {
    inside(base, p.relative(f.path, from: base));
  }
  final order = c.suite;
  files.sort((a, b) {
    int rank(File f) {
      final i = order.indexOf(
        p.relative(f.path, from: base).replaceAll('\\', '/'),
      );
      return i < 0 ? order.length : i;
    }

    final compare = rank(a).compareTo(rank(b));
    return compare != 0 ? compare : a.path.compareTo(b.path);
  });
  if (target == 'gherkin' && order.isNotEmpty) {
    for (final name in order) {
      if (!File(inside(base, name)).existsSync()) {
        throw GherkinException('Suite member missing: $name');
      }
    }
  }
  return files;
}
