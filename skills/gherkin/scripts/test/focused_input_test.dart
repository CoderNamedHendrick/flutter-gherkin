import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:gherkin_tools/src/config.dart';
import 'package:gherkin_tools/src/dialect.dart';
import 'package:gherkin_tools/src/generator.dart';
import 'package:gherkin_tools/src/install.dart';
import 'package:gherkin_tools/src/launch.dart';
import 'package:gherkin_tools/src/recording.dart';
import 'package:gherkin_tools/src/redaction.dart';
import 'package:gherkin_tools/src/runner.dart';

void main() {
  late Directory root;
  late ProjectConfig config;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gherkin-focused-');
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(
      "name: example\nenvironment:\n  sdk: '>=3.11.0 <4.0.0'\ndependencies:\n  flutter:\n    sdk: flutter\n",
    );
    scaffold(
      root.path,
      app: root.path,
      environment: 'local',
      patrol: true,
      platforms: ['ios'],
    );
    config = ProjectConfig.load(root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));
  Feature feature(String steps) => parseFeature(
    'Feature: Focus\n Scenario: Entry\n$steps',
    path: p.join(root.path, 'gherkin/features/focus.feature'),
  );

  test(
    'focused entry parses empty, escaped and placeholder values precisely',
    () {
      for (final value in ['', 'hello "world"\n', r'${env:TEST_PASSWORD}']) {
        final step = parseStep(
          'I enter ${jsonEncode(value)} into the focused field',
          1,
        );
        expect(step.args, [value]);
        expect(step.textInput, true);
        expect(step.supports(Backend.marionetteMcp), true);
        expect(step.supports(Backend.patrol), true);
        expect(step.supports(Backend.marionetteCli), false);
      }
      expect(
        () => parseStep('I enter "x" into the focused field keyed "k"', 1),
        throwsA(isA<GherkinException>()),
      );
    },
  );

  test(
    'support checks include fixture steps and reject CLI before actions',
    () async {
      final c = ProjectConfig(root.path, {
        ...config.data,
        'fixtures': {
          'search': ['I enter "public query" into the focused field'],
        },
      });
      final f = feature(
        '  When I tap the widget keyed "open"\n  And I select the fixture "search"',
      );
      validateSupport(f, Backend.marionetteMcp, expand: c.expand);
      validateSupport(f, Backend.patrol, expand: c.expand);
      final driver = RecordingDriver(backend: Backend.marionetteCli);
      final evidence = Directory(p.join(root.path, 'gherkin/evidence'));
      final before = evidence
          .listSync(recursive: true)
          .map((f) => f.path)
          .toList();
      await expectLater(
        runSuite(c, [f], {'default': driver}),
        throwsA(isA<GherkinException>()),
      );
      expect(driver.actions, isEmpty);
      expect(
        evidence.listSync(recursive: true).map((f) => f.path).toList(),
        before,
      );
      await expectLater(
        CliDriver(
          'unused',
          executable: 'must-not-be-invoked',
        ).action(parseStep('I enter "x" into the focused field', 1)),
        throwsA(isA<GherkinException>()),
      );
      expect(
        () => validateSupport(
          feature('  Given I use actor "alice"'),
          Backend.marionetteCli,
        ),
        throwsA(isA<GherkinException>()),
      );
    },
  );

  test(
    'focused placeholder resolves at dispatch and never reaches evidence',
    () async {
      final driver = RecordingDriver(fail: true);
      final f = feature(
        r'  When I enter "${env:TEST_PASSWORD}" into the focused field',
      );
      final report = await runSuite(
        config,
        [f],
        {'default': driver},
        valueResolver: (_) => 'secret /with?encoding',
      );
      expect(driver.actions.single.args, ['secret /with?encoding']);
      expect(driver.actions.single.support, Support.mcpAndPatrol);
      expect(report['failed'], 1);
      final evidence = Directory(p.dirname(report['report'] as String));
      for (final file in evidence.listSync().whereType<File>()) {
        expect(
          file.readAsStringSync(),
          isNot(contains('secret /with?encoding')),
        );
        expect(
          file.readAsStringSync(),
          isNot(contains(Uri.encodeComponent('secret /with?encoding'))),
        );
      }
    },
  );

  test(
    'missing focused placeholder fails before even the first action',
    () async {
      final driver = RecordingDriver();
      final f = feature(
        '  When I tap the widget keyed "open"\n'
        r'  And I enter "${env:GHERKIN_TEST_UNSET_62C73}" into the focused field',
      );
      await expectLater(
        runSuite(config, [f], {'default': driver}),
        throwsA(isA<GherkinException>()),
      );
      expect(driver.actions, isEmpty);
    },
  );

  test(
    'unkeyed recording collapses only a known focus session and keeps navigation boundaries',
    () {
      var seq = 0;
      String event(String action, Map<String, dynamic> fields) =>
          '[GHERKIN_REC] ${jsonEncode({'session': 's', 'seq': seq++, 'action': action, ...fields})}';
      final result = convertRecording(
        [
          event('enter_text', {'focus': 'f1', 'value': 'never-copy-first'}),
          event('enter_text', {'focus': 'f1', 'value': 'never-copy-final'}),
          event('focus', {'focus': 'f2'}),
          event('enter_text', {'focus': 'f2', 'value': 'never-copy-other'}),
          event('nav', {'route': '/search'}),
          event('enter_text', {'focus': 'f2', 'value': 'never-copy-after-nav'}),
          event('enter_text', {'value': 'never-copy-legacy-one'}),
          event('enter_text', {'value': 'never-copy-legacy-two'}),
        ].join('\n'),
        'search',
      );
      final steps = parseFeature(
        result.feature,
      ).scenarios.single.steps.where((s) => s.textInput).toList();
      expect(steps, hasLength(5));
      expect(steps[0].args, [r'${fixture:unkeyed_field_f1}']);
      expect(steps[1].args, [r'${fixture:unkeyed_field_f2}']);
      expect(result.gaps, isEmpty);
      expect(result.feature, isNot(contains('never-copy')));
      expect(parseFeature(result.feature).tags, contains('draft'));
    },
  );

  test(
    'generation inherits root formatting and leaves bootstrap and analyzer settings intact',
    () async {
      final options = File(p.join(root.path, 'analysis_options.yaml'))
        ..writeAsStringSync(
          'formatter:\n  page_width: 120\nlinter:\n  rules:\n    prefer_const_constructors: true\n',
        );
      final bootstrap = File(p.join(root.path, config.bootstrap))
        ..writeAsStringSync('// Customized bootstrap; preserve verbatim.\n');
      final beforeOptions = options.readAsStringSync();
      final f = File(p.join(root.path, 'gherkin/features/focus.feature'))
        ..writeAsStringSync(
          'Feature: Focus\n Scenario: Enter into search\n'
          '  When I tap the widget keyed "a_long_search_anchor_key_that_keeps_the_formatter_test_between_eighty_and_one_twenty"\n'
          r'  And I enter "${fixture:search_query}" into the focused field',
        );
      final outputs = await generateSuite(config, [f]);
      final generated = File(outputs.single).readAsStringSync();
      expect(generated, contains('const ValueKey<String>'));
      expect(generated, contains(r'resolveValue("\${fixture:search_query}")'));
      expect(generated, contains('gherkinFocusedField()'));
      final formatted = await Process.run(Platform.resolvedExecutable, [
        'format',
        '--set-exit-if-changed',
        outputs.single,
      ], workingDirectory: root.path);
      expect(
        formatted.exitCode,
        0,
        reason: '${formatted.stdout}\n${formatted.stderr}',
      );
      expect(File(outputs.single).readAsStringSync(), generated);
      expect(
        generated
            .split('\n')
            .any((line) => line.length > 80 && line.length <= 120),
        true,
      );
      await generateSuite(config, [f], check: true);
      expect(options.readAsStringSync(), beforeOptions);
      expect(
        bootstrap.readAsStringSync(),
        '// Customized bootstrap; preserve verbatim.\n',
      );
      expect(
        File(
          p.join(root.path, 'integration_test/analysis_options.yaml'),
        ).existsSync(),
        false,
      );
    },
  );

  test(
    'formatter command follows project SDK selection and supports custom wrappers',
    () {
      for (final wrapper in ['fvm', 'puro']) {
        final c = ProjectConfig(root.path, {
          ...config.data,
          'flutter_command': [wrapper, 'flutter'],
        });
        expect(c.dart, [wrapper, 'dart']);
      }
      expect(
        ProjectConfig(root.path, {
          ...config.data,
          'flutter_command': ['/some/flutter/bin/flutter'],
        }).dart,
        ['/some/flutter/bin/dart'],
      );
      expect(
        ProjectConfig(root.path, {
          ...config.data,
          'flutter_command': ['custom-flutter'],
          'dart_command': ['custom-dart'],
        }).dart,
        ['custom-dart'],
      );
    },
  );

  test('structured log redaction preserves event types and placeholders', () {
    final input =
        '[GHERKIN_REC] ${jsonEncode({'session': 's', 'seq': 123, 'action': 'enter_text', 'sensitive': true, 'value': r'${fixture:secret_field}', 'text': '123 true secret'})}';
    final output = LogRedactor(['123', 'true', 'secret']).redact(input);
    final event = jsonDecode(output.substring(14)) as Map;
    expect(event['seq'], 123);
    expect(event['sensitive'], true);
    expect(event['value'], r'${fixture:secret_field}');
    expect(event['text'], '[REDACTED] [REDACTED] [REDACTED]');
    expect(
      jsonDecode(
        LogRedactor([]).redact(
          jsonEncode({
            'headers': {'Authorization': 'Bearer unknown-value'},
          }),
        ),
      ),
      {
        'headers': {'Authorization': '[REDACTED]'},
      },
    );
  });

  test(
    'define redaction matches Flutter content detection and dotenv quoting',
    () {
      File(
        p.join(root.path, 'local.defines'),
      ).writeAsStringSync(jsonEncode({'TMDB_API_KEY': 'json-secret'}));
      File(p.join(root.path, 'local.env')).writeAsStringSync(
        'API_KEY="quoted #secret" # comment\nACCESS_TOKEN=plain-secret # comment\n',
      );
      final c = ProjectConfig(root.path, {
        ...config.data,
        'dart_define_files': ['local.defines', 'local.env'],
      });
      final redactor = LogRedactor.fromConfig(c);
      expect(
        redactor.redact('json-secret quoted #secret plain-secret'),
        '[REDACTED] [REDACTED] [REDACTED]',
      );
    },
  );

  test(
    'CLI backend validation rejects focused entry before connecting',
    () async {
      File(
        p.join(root.path, 'gherkin/features/focus.feature'),
      ).writeAsStringSync(
        'Feature: Focus\n Scenario: S\n  When I enter "hello" into the focused field',
      );
      final command = p.absolute('bin/gherkin.dart');
      for (final args in [
        ['validate', 'focus', '--backend', 'marionetteCli'],
        ['run-cli', 'focus', '--uri', 'ws://127.0.0.1:1/unused'],
      ]) {
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          command,
          ...args,
          '--root',
          root.path,
        ]);
        expect(result.exitCode, 2);
        expect(
          result.stderr,
          contains('enter_focused unsupported by marionetteCli'),
        );
      }
    },
  );

  test(
    'log redaction covers encoded values, credential queries and auth headers',
    () {
      final redactor = LogRedactor(['secret /with?encoding']);
      final filtered = redactor.redact(
        'literal secret /with?encoding\n'
        '${Uri.encodeComponent('secret /with?encoding')}\n'
        'https://example.test?q=public&api_key=hidden&access_token=other&%6Bey=encoded-name\n'
        'Authorization: Bearer bearer-value\nAuthorization: Basic basic-value',
      );
      for (final secret in [
        'secret /with?encoding',
        'hidden',
        'other',
        'encoded-name',
        'bearer-value',
        'basic-value',
      ]) {
        expect(filtered, isNot(contains(secret)));
      }
      expect(filtered, contains('q=public'));
    },
  );

  test(
    'launch sanitizes stdout, stderr and every machine app log before writing',
    () async {
      final defines = File(p.join(root.path, 'local.json'))
        ..writeAsStringSync(
          jsonEncode({'TMDB_API_KEY': 'private-define-value'}),
        );
      final fake = File(p.join(root.path, 'fake_flutter.dart'))
        ..writeAsStringSync('''
import 'dart:convert';
import 'dart:io';
void main(List<String> args) {
  stdout.writeln(jsonEncode([
    {'event':'app.log','params':{'log':'first private-define-value'}},
    {'event':'app.log','params':{'log':'second https://example.test?api_key=unknown-secret'}},
  ]));
  stderr.writeln('Authorization: Bearer stderr-secret');
  stdout.writeln('[{"event":"app.debugPort","params":{"wsUri":"ws://localhost:1234/session/ws"}}]');
}
''');
      final c = ProjectConfig(root.path, {
        ...config.data,
        'flutter_command': [Platform.resolvedExecutable, fake.path],
        'dart_define_files': [p.basename(defines.path)],
        'default_device': 'fake',
      });
      await launch(c);
      final log = Directory(
        p.join(root.path, 'gherkin/evidence/logs'),
      ).listSync().whereType<File>().single.readAsStringSync();
      expect(log, contains('first [REDACTED]'));
      expect(log, contains('second https://example.test?api_key=[REDACTED]'));
      expect(log, contains('Authorization: [REDACTED]'));
      for (final secret in [
        'private-define-value',
        'unknown-secret',
        'stderr-secret',
      ]) {
        expect(log, isNot(contains(secret)));
      }
    },
  );
}

class RecordingDriver implements Driver {
  RecordingDriver({this.backend = Backend.marionetteMcp, this.fail = false});
  @override
  final Backend backend;
  final bool fail;
  final actions = <Step>[];
  @override
  Future<void> action(Step step) async {
    actions.add(step);
    if (fail) throw GherkinException('failed for ${step.args.first}');
  }

  @override
  Future<List<Map<String, dynamic>>> elements() async => [];
  @override
  Future<void> screenshot(String path) async =>
      File(path).writeAsStringSync('image fixture');
  @override
  Future<String> logs() async =>
      'secret /with?encoding ${Uri.encodeComponent('secret /with?encoding')}';
}
