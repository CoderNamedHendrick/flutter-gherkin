import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:gherkin_tools/src/config.dart';
import 'package:gherkin_tools/src/dialect.dart';
import 'package:gherkin_tools/src/doctor.dart';
import 'package:gherkin_tools/src/generator.dart';
import 'package:gherkin_tools/src/install.dart';
import 'package:gherkin_tools/src/launch.dart';
import 'package:gherkin_tools/src/recording.dart';
import 'package:gherkin_tools/src/runner.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('root', defaultsTo: Directory.current.path)
    ..addOption('app')
    ..addOption('environment')
    ..addOption('entrypoint', defaultsTo: 'lib/main.dart')
    ..addOption('flavor')
    ..addMultiOption('platforms', defaultsTo: ['ios', 'android'])
    ..addOption('device')
    ..addOption('uri')
    ..addOption('log')
    ..addOption('name')
    ..addOption('manifest')
    ..addFlag('confirmed-order', negatable: false)
    ..addFlag('patrol', negatable: false)
    ..addFlag('record', negatable: false)
    ..addFlag('probe', negatable: false)
    ..addFlag('json', negatable: false)
    ..addFlag('confirm-production', negatable: false)
    ..addFlag('help', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args['help'] == true || args.rest.isEmpty) {
      stdout.writeln(
        'Commands: doctor, inspect, scaffold, validate, parse-recording, stitch-recordings, launch, vm-uri, run-cli, generate-patrol, check-generated, patrol-directory\n${parser.usage}',
      );
      return;
    }
    final root = p.normalize(p.absolute(args['root'] as String));
    final command = args.rest.first;
    final target = args.rest.length > 1 ? args.rest[1] : 'gherkin';
    void output(Object? value) =>
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(value));
    if (command == 'doctor') {
      final rows = await doctor(root, probe: args['probe'] as bool);
      if (args['json'] == true) {
        stdout.writeln(doctorJson(rows));
      } else {
        for (final row in rows) {
          stdout.writeln(
            '${row['status']}: ${row['check']} — ${row['detail']}',
          );
        }
      }
      if (rows.any((r) => r['status']!.startsWith('FAIL'))) exitCode = 1;
      return;
    }
    if (command == 'inspect') {
      output([
        for (final app in findApps(root)) {'root': app, ...inspectApp(app)},
      ]);
      return;
    }
    if (command == 'vm-uri') {
      final log = args['log'] as String?;
      if (log == null) throw GherkinException('--log required');
      final uri = vmUri(File(log).readAsStringSync());
      if (uri == null) throw GherkinException('No VM service URI found');
      output({'uri': uri});
      return;
    }
    if (command == 'scaffold') {
      final env = args['environment'] as String?;
      if (env == null) {
        throw GherkinException(
          '--environment required; infer from project or ask user',
        );
      }
      final apps = findApps(root);
      final app = args['app'] as String?;
      if (app == null && apps.length != 1) {
        throw GherkinException(
          'Specify --app relative to --root; found ${apps.length} apps',
        );
      }
      final selected = app == null ? apps.single : inside(root, app);
      output({
        'changed': scaffold(
          root,
          app: selected,
          environment: env,
          patrol: args['patrol'] as bool,
          platforms: args['platforms'] as List<String>,
          entrypoint: args['entrypoint'] as String,
          flavor: args['flavor'] as String?,
        ),
        'remaining':
            'Install dependencies, inspect and integrate bootstrap, configure selected MCP host and run smoke tests per references/install.md',
      });
      return;
    }
    final c = ProjectConfig.load(root);
    if (command == 'patrol-directory') {
      configurePatrolDirectory(c);
      output({'ok': true});
      return;
    }
    if (command == 'launch') {
      await launch(
        c,
        record: args['record'] as bool,
        device: args['device'] as String?,
        confirmProduction: args['confirm-production'] as bool,
      );
      return;
    }
    if (command == 'stitch-recordings') {
      if (args['confirmed-order'] != true) {
        throw GherkinException(
          'First ask the user to confirm the explicit actor segment order',
        );
      }
      final manifestPath = args['manifest'] as String?;
      final name = args['name'] as String?;
      if (manifestPath == null || name == null) {
        throw GherkinException('--manifest and --name required');
      }
      final manifest = stringMap(
        jsonDecode(File(inside(root, manifestPath)).readAsStringSync()),
        'manifest',
      );
      final segments = (manifest['segments'] as List)
          .map((v) => stringMap(v, 'segment'))
          .toList();
      final logs = <String, String>{};
      for (final entry in stringMap(manifest['logs'], 'logs').entries) {
        if (!c.actors.containsKey(entry.key)) {
          throw GherkinException('Unconfigured actor ${entry.key}');
        }
        logs[entry.key] = File(
          inside(root, entry.value as String),
        ).readAsStringSync();
      }
      final recording = stitchRecordings(
        segments,
        logs,
        name,
        publicKeys: Set<String>.from(c.data['public_text_keys'] ?? []),
        sensitiveKeys: Set<String>.from(c.data['sensitive_keys'] ?? []),
      );
      final file = File(inside(root, 'gherkin/features/$name.feature'));
      if (file.existsSync()) {
        throw GherkinException('Feature exists; merge explicitly');
      }
      file.writeAsStringSync(recording.feature);
      output({
        'feature': file.path,
        'gaps': recording.gaps,
        'status': 'draft; confirm assertions',
      });
      return;
    }
    if (command == 'parse-recording') {
      final log = args['log'] as String?;
      final name = args['name'] as String?;
      if (log == null || name == null) {
        throw GherkinException('--log and --name required');
      }
      final rec = convertRecording(
        File(log).readAsStringSync(),
        name,
        publicKeys: Set<String>.from(c.data['public_text_keys'] ?? []),
        sensitiveKeys: Set<String>.from(c.data['sensitive_keys'] ?? []),
      );
      final file = File(inside(root, 'gherkin/features/$name.feature'));
      if (file.existsSync()) {
        throw GherkinException(
          'Feature already exists; choose a new name or merge explicitly',
        );
      }
      file.writeAsStringSync(rec.feature);
      output({
        'feature': file.path,
        'events': rec.events,
        'gaps': rec.gaps,
        'status': 'draft; confirm assertions before replay',
      });
      return;
    }
    final files = resolveFeatures(c, target);
    final features = files
        .map((f) => parseFeature(f.readAsStringSync(), path: f.path))
        .toList();
    switch (command) {
      case 'validate':
        output({
          'valid': true,
          'features': [
            for (final f in features)
              {
                'path': f.path,
                'scenarios': f.scenarios.length,
                'steps': f.allSteps.map((s) => s.toJson()).toList(),
              },
          ],
        });
      case 'generate-patrol':
      case 'check-generated':
        final generated = await generateSuite(
          c,
          files,
          check: command == 'check-generated',
        );
        if (command == 'generate-patrol') {
          final result = await Process.run(c.flutter.first, [
            ...c.flutter.skip(1),
            'analyze',
            p.join(root, 'gherkin/generated/patrol'),
            p.join(root, 'gherkin/support'),
          ], workingDirectory: c.appRoot);
          if (result.exitCode != 0) {
            stderr.writeln(result.stdout);
            throw GherkinException(
              'Generated Dart analysis failed; output is not ready to execute',
            );
          }
        }
        output({'files': generated, 'in_sync': true});
      case 'run-cli':
        final uri = args['uri'] as String?;
        if (uri == null) {
          throw GherkinException('--uri required; launch/reconnect first');
        }
        if (features.any((f) => f.allSteps.any((s) => s.kind == 'actor'))) {
          throw GherkinException(
            'Multi-device replay requires dedicated live MCP connections; CLI fallback is single-device only',
          );
        }
        final report = await runSuite(c, features, {
          'default': CliDriver(uri),
        }, confirmProduction: args['confirm-production'] as bool);
        output(report);
        if (report['failed'] != 0) exitCode = 1;
      default:
        throw GherkinException('Unknown command $command; use --help');
    }
  } on GherkinException catch (e) {
    stderr.writeln(jsonEncode({'error': e.message}));
    exitCode = 2;
  } on FormatException {
    stderr.writeln('{"error":"Invalid data or arguments; use --help"}');
    exitCode = 2;
  } on FileSystemException catch (e) {
    stderr.writeln(jsonEncode({'error': 'File access failed', 'path': e.path}));
    exitCode = 2;
  }
}
