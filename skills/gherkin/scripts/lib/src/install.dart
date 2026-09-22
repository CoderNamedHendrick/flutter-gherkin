import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'config.dart';
import 'dialect.dart';

String skillDirectory() => File.fromUri(
  Isolate.resolvePackageUriSync(
    Uri.parse('package:gherkin_tools/src/install.dart'),
  )!,
).parent.parent.parent.parent.path;
List<String> detectFlutter(String root) =>
    File(p.join(root, '.fvmrc')).existsSync() ||
        Directory(p.join(root, '.fvm')).existsSync()
    ? ['fvm', 'flutter']
    : File(p.join(root, '.puro.json')).existsSync()
    ? ['puro', 'flutter']
    : ['flutter'];
List<String> findApps(String root) {
  final result = <String>[];
  void walk(Directory dir, int depth) {
    if (depth > 5) return;
    final pub = File(p.join(dir.path, 'pubspec.yaml'));
    if (pub.existsSync()) {
      final data = loadYaml(pub.readAsStringSync());
      if (data is Map &&
          data['dependencies'] is Map &&
          data['dependencies']['flutter'] != null &&
          Directory(p.join(dir.path, 'lib')).existsSync()) {
        result.add(dir.path);
      }
    }
    for (final e in dir.listSync(followLinks: false)) {
      if (e is Directory &&
          !p.basename(e.path).startsWith('.') &&
          !['build', 'node_modules'].contains(p.basename(e.path))) {
        walk(e, depth + 1);
      }
    }
  }

  walk(Directory(root), 0);
  return result;
}

Map<String, dynamic> inspectApp(String app) {
  final lib = Directory(p.join(app, 'lib'));
  final sources = lib.existsSync()
      ? lib
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
      : <File>[];
  final entrypoints = sources
      .where(
        (f) => RegExp(
          r'^\s*(?:void|Future(?:<void>)?)\s+main\s*\(',
          multiLine: true,
        ).hasMatch(f.readAsStringSync()),
      )
      .map((f) => p.relative(f.path, from: app))
      .toList();
  final bindings = sources
      .where(
        (f) => RegExp(
          r'(Binding|SentryFlutter).*?(ensureInitialized|init)\(',
        ).hasMatch(f.readAsStringSync()),
      )
      .map((f) => p.relative(f.path, from: app))
      .toList();
  final flavors = <String>{};
  for (final name in [
    'android/app/build.gradle',
    'android/app/build.gradle.kts',
  ]) {
    final f = File(p.join(app, name));
    if (!f.existsSync()) continue;
    final text = f.readAsStringSync();
    if (text.contains('productFlavors')) {
      flavors.addAll(
        RegExp(
          r'''(?:create\(|getByName\()\s*["']([^"']+)["']''',
        ).allMatches(gradleBlock(text, 'productFlavors')).map((m) => m[1]!),
      );
      flavors.addAll(
        RegExp(
          r'^\s+(\w+)\s*\{\s*\n\s*(?:dimension|applicationIdSuffix)',
          multiLine: true,
        ).allMatches(gradleBlock(text, 'productFlavors')).map((m) => m[1]!),
      );
    }
  }
  final schemes = Directory(
    p.join(app, 'ios/Runner.xcodeproj/xcshareddata/xcschemes'),
  );
  if (schemes.existsSync()) {
    flavors.addAll(
      schemes
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.xcscheme') &&
                p.basenameWithoutExtension(f.path) != 'Runner',
          )
          .map((f) => p.basenameWithoutExtension(f.path)),
    );
  }
  return {
    'entrypoints': entrypoints,
    'binding_sites': bindings,
    'flavors': flavors.toList()..sort(),
    'flutter_command': detectFlutter(app),
  };
}

List<String> scaffold(
  String root, {
  required String app,
  required String environment,
  required bool patrol,
  required List<String> platforms,
  String entrypoint = 'lib/main.dart',
  String? flavor,
}) {
  final changed = <String>[];
  void create(String path, String content) {
    final file = File(inside(root, path));
    if (file.existsSync()) return;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    changed.add(path);
  }

  final rel = p.relative(app, from: root);
  final config = {
    'version': 1,
    'app_root': rel,
    'entrypoint': entrypoint,
    'flutter_command': detectFlutter(app),
    'flavor': flavor,
    'environment': environment,
    'allowed_environments': [environment],
    'production': false,
    'dart_define_files': <String>[],
    'default_device': null,
    'platforms': platforms,
    'suite': <String>[],
    'fixtures': <String, dynamic>{},
    'actors': <String, dynamic>{},
    'marionette': {'preference': 'auto'},
    'patrol': {
      'enabled': patrol,
      'preference': 'auto',
      'bootstrap': 'gherkin/support/patrol_bootstrap.dart',
    },
    'agent': {'name': null, 'config_path': null},
    'public_text_keys': <String>[],
    'sensitive_keys': <String>[],
  };
  ProjectConfig(
    root,
    config,
  ); // Validate proposed facts before writing any files.
  create(
    'gherkin/config.yaml',
    '${const JsonEncoder.withIndent('  ').convert(config)}\n',
  ); // JSON is valid YAML; preserve existing config byte-for-byte.
  for (final dir in [
    'features',
    'fixtures',
    'generated/patrol',
    'evidence/screenshots',
    'evidence/logs',
    'support',
  ]) {
    Directory(inside(root, 'gherkin/$dir')).createSync(recursive: true);
  }
  create(
    'gherkin/README.md',
    '# App Gherkin tests\n\nEdit features, regenerate and commit Patrol output. Evidence and local secrets are ignored. Run check-generated in CI. Configure fixture adapters before using them. See the installed gherkin skill for workflows.\n',
  );
  for (final name in ['binding.dart', 'recorder.dart']) {
    create(
      p.join(rel, 'lib/gherkin_harness', name),
      File(
        p.join(skillDirectory(), 'assets/flutter-harness', name),
      ).readAsStringSync(),
    );
  }
  if (patrol) {
    create(
      'gherkin/support/patrol_bootstrap.dart',
      File(
        p.join(skillDirectory(), 'assets/project/patrol_bootstrap.dart'),
      ).readAsStringSync(),
    );
  }
  final ignore = File(inside(root, '.gitignore'));
  final current = ignore.existsSync() ? ignore.readAsStringSync() : '';
  final additions = [
    '/gherkin/evidence/',
    '/gherkin/local.*',
    '**/test_bundle.dart',
    '.patrol.env',
  ].where((s) => !current.split('\n').contains(s)).toList();
  if (additions.isNotEmpty) {
    ignore.writeAsStringSync(
      '$current${current.isNotEmpty && !current.endsWith('\n') ? '\n' : ''}${additions.join('\n')}\n',
    );
    changed.add('.gitignore');
  }
  return changed;
}

void configurePatrolDirectory(ProjectConfig config) {
  final f = File(inside(config.appRoot, 'pubspec.yaml'));
  final editor = YamlEditor(f.readAsStringSync());
  final data = loadYaml(f.readAsStringSync()) as Map;
  final relative = p
      .relative(
        p.join(config.root, 'gherkin/generated/patrol'),
        from: config.appRoot,
      )
      .replaceAll('\\', '/');
  if (data['patrol'] == null) {
    editor.update(['patrol'], {'test_directory': relative});
  } else {
    final existing = (data['patrol'] as Map)['test_directory'];
    if (existing != null && existing != relative) {
      throw GherkinException(
        'Existing Patrol test_directory differs; merge suite deliberately before changing it',
      );
    }
    editor.update(['patrol', 'test_directory'], relative);
  }
  f.writeAsStringSync(editor.toString());
}

String chooseBackend({
  required String preference,
  required bool loaded,
  required bool cli,
  bool registered = false,
}) {
  if (preference != 'cli' && loaded) return 'mcp';
  if (preference != 'mcp' && cli) return 'cli';
  if (registered) {
    throw GherkinException(
      'MCP registered but not loaded: restart host to use these tools',
    );
  }
  throw GherkinException(
    'No requested backend available; install CLI or register/load MCP',
  );
}

// Scope discovery to the actual block so buildTypes.getByName("debug") isn't a flavor.
String gradleBlock(String source, String name) {
  final match = RegExp('$name\\s*\\{').firstMatch(source);
  if (match == null) return '';
  var depth = 1;
  String? quote;
  for (var i = match.end; i < source.length; i++) {
    final c = source[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
        continue;
      }
      if (c == quote) quote = null;
      continue;
    }
    if (c == '"' || c == "'") {
      quote = c;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) return source.substring(match.end, i);
  }
  throw GherkinException('Unclosed $name block; inspect Gradle manually');
}
