import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:gherkin_tools/src/config.dart';
import 'package:gherkin_tools/src/dialect.dart';
import 'package:gherkin_tools/src/doctor.dart';
import 'package:gherkin_tools/src/generator.dart';
import 'package:gherkin_tools/src/install.dart';
import 'package:gherkin_tools/src/launch.dart';
import 'package:gherkin_tools/src/recording.dart';
import 'package:gherkin_tools/src/runner.dart';

void main() {
  late Directory root;
  late ProjectConfig config;
  setUp(() {
    root = Directory.systemTemp.createTempSync('gherkin-test-');
    Directory(p.join(root.path, 'lib')).createSync();
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(
      'name: example\ndependencies:\n  flutter:\n    sdk: flutter\n',
    );
    File(p.join(root.path, 'lib/main.dart')).writeAsStringSync(
      'void main() { WidgetsFlutterBinding.ensureInitialized(); }',
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
  test(
    'version compatibility distinguishes project CLI, old global CLI and unknown releases',
    () {
      expect(patrolCompatibility('4.8.0', '4.10.0'), true);
      expect(patrolCompatibility('3.10.0', '4.10.0'), false);
      expect(patrolCompatibility('5.0.0', '5.0.0'), isNull);
    },
  );
  test('doctor is read-only and distinguishes missing integration', () async {
    Map<String, String> snapshot() => {
      for (final f in root.listSync(recursive: true).whereType<File>())
        f.path: f.readAsStringSync(),
    };
    final before = snapshot();
    final result = await doctor(root.path);
    expect(snapshot(), before);
    expect(
      result.singleWhere((r) => r['check'] == 'Recording harness')['status'],
      startsWith('FAIL'),
    );
    expect(
      result.singleWhere((r) => r['check'] == 'MCP registration')['status'],
      startsWith('WARN'),
    );
  });
  test('scaffold refuses an escaping gitignore symlink', () {
    final outside = Directory.systemTemp.createTempSync('gherkin-outside-');
    try {
      final target = File(p.join(outside.path, 'ignore'))
        ..writeAsStringSync('unchanged');
      File(p.join(root.path, '.gitignore')).deleteSync();
      Link(p.join(root.path, '.gitignore')).createSync(target.path);
      expect(
        () => scaffold(
          root.path,
          app: root.path,
          environment: 'local',
          patrol: true,
          platforms: ['ios'],
        ),
        throwsA(isA<GherkinException>()),
      );
      expect(target.readAsStringSync(), 'unchanged');
    } finally {
      outside.deleteSync(recursive: true);
    }
  });

  test('scaffold preserves config and templates byte-for-byte on repeat', () {
    final f = File(p.join(root.path, 'gherkin/config.yaml'));
    final before = f.readAsStringSync();
    final source = File(p.join(root.path, 'lib/main.dart')).readAsStringSync();
    expect(
      scaffold(
        root.path,
        app: root.path,
        environment: 'different',
        patrol: true,
        platforms: ['android'],
      ),
      isEmpty,
    );
    expect(f.readAsStringSync(), before);
    expect(File(p.join(root.path, 'lib/main.dart')).readAsStringSync(), source);
  });
  test(
    'config rejects unknown keys, bad types, unsafe environments and path escapes',
    () {
      for (final extra in [
        {'unexpected': true},
        {'production': null},
        {'flavor': []},
        {
          'patrol': {'bootstrap': 3},
        },
        {
          'agent': {'config_path': false},
        },
        {'environment': 'production'},
        {'entrypoint': '../../main.dart'},
        {'suite': false},
        {
          'fixtures': {
            'x': ['I select the fixture "x"'],
          },
        },
      ]) {
        expect(
          () => ProjectConfig(root.path, {...config.data, ...extra}),
          throwsA(isA<GherkinException>()),
        );
      }
      expect(
        () => inside(root.path, '../outside'),
        throwsA(isA<GherkinException>()),
      );
      final prod = ProjectConfig(root.path, {
        ...config.data,
        'environment': 'production',
        'allowed_environments': ['production'],
        'production': true,
      });
      expect(() => prod.guard(), throwsA(isA<GherkinException>()));
      prod.guard(confirmProduction: true);
    },
  );
  test('detects monorepos, toolchain pin, flavors and binding candidates', () {
    File(p.join(root.path, '.fvmrc')).writeAsStringSync('{}');
    final build = File(p.join(root.path, 'android/app/build.gradle.kts'))
      ..parent.createSync(recursive: true);
    build.writeAsStringSync(
      'productFlavors { create("dev") { dimension = "env" } }',
    );
    final info = inspectApp(root.path);
    expect(info['flavors'], ['dev']);
    expect(info['flutter_command'], ['fvm', 'flutter']);
    expect(info['binding_sites'], contains('lib/main.dart'));
    expect(findApps(root.path), [root.path]);
  });
  test(
    'capabilities prefer loaded MCP, fall back CLI, distinguish restart',
    () {
      expect(chooseBackend(preference: 'auto', loaded: true, cli: true), 'mcp');
      expect(
        chooseBackend(
          preference: 'auto',
          loaded: false,
          cli: true,
          registered: true,
        ),
        'cli',
      );
      expect(
        () => chooseBackend(
          preference: 'mcp',
          loaded: false,
          cli: true,
          registered: true,
        ),
        throwsA(isA<GherkinException>()),
      );
    },
  );
  test(
    'recording sorts, collapses text, redacts before feature and surfaces gaps',
    () {
      String e(int seq, String action, Map<String, dynamic> values) =>
          '[GHERKIN_REC] ${jsonEncode({'session': 's', 'seq': seq, 'action': action, ...values})}';
      final log = [
        e(3, 'enter_text', {'key': 'name', 'value': 'Ada'}),
        e(1, 'tap', {'key': 'name'}),
        e(2, 'enter_text', {'key': 'name', 'value': 'A'}),
        e(4, 'enter_text', {'key': 'password', 'value': 'do-not-save'}),
        e(5, 'tap', {'type': 'CustomButton', 'x': 12, 'y': 24}),
        e(6, 'nav', {'route': '/success'}),
      ].join('\n');
      final r = convertRecording(
        log,
        'login',
        publicKeys: {'name', 'password'},
      );
      expect(r.feature, contains('I enter "Ada"'));
      expect(r.feature, isNot(contains('I enter "A"')));
      expect(r.feature, isNot(contains('do-not-save')));
      expect(r.feature, contains(r'${fixture:password}'));
      expect(r.gaps.single['suggested_key'], 'login_control_1');
      expect(r.feature, isNot(contains('    Then ')));
      expect(parseFeature(r.feature).tags, ['draft']);
      expect(
        () => validateSupport(parseFeature(r.feature), 'marionette'),
        throwsA(isA<GherkinException>()),
      );
    },
  );
  test('malformed/mixed/duplicate recordings fail without leaking input', () {
    for (final log in [
      '[GHERKIN_REC] {"value":"secret"}',
      '[GHERKIN_REC] {"seq":1,"action":"tap","session":"a"}\n[GHERKIN_REC] {"seq":1,"action":"tap","session":"b"}',
    ]) {
      expect(
        () => convertRecording(log, 'flow'),
        throwsA(isA<GherkinException>()),
      );
    }
  });
  test('multi-device recording uses explicit segments, never timestamps', () {
    String event(String actor, int seq, String key) =>
        '[GHERKIN_REC] ${jsonEncode({'session': actor, 'actor': actor, 'seq': seq, 'action': 'tap', 'key': key})}';
    final logs = {
      'a': '${event('a', 0, 'first')}\n${event('a', 1, 'last')}',
      'b': event('b', 0, 'middle'),
    };
    final segments = [
      {'actor': 'a', 'session': 'a', 'start_seq': 0, 'end_seq': 0},
      {'actor': 'b', 'session': 'b', 'start_seq': 0, 'end_seq': 0},
      {'actor': 'a', 'session': 'a', 'start_seq': 1, 'end_seq': 1},
    ];
    final recording = stitchRecordings(segments, logs, 'chat');
    final steps = parseFeature(recording.feature).scenarios.single.steps;
    expect(steps.where((s) => s.kind == 'tap_key').map((s) => s.args.single), [
      'first',
      'middle',
      'last',
    ]);
    expect(
      () => stitchRecordings([...segments, segments.first], logs, 'chat'),
      throwsA(isA<GherkinException>()),
    );
  });
  test('Dart escaping prevents interpolation and handles controls', () {
    expect(dartString('a\n"\\\$value'), r'"a\n\"\\\$value"');
  });
  test(
    'generation stable, stale checks detect edits, rejected batch leaves files intact',
    () async {
      final f = File(p.join(root.path, 'gherkin/features/a.feature'));
      const source =
          'Feature: A\n Scenario: S\n  When I tap the widget keyed "go"\n  Then the widget keyed "done" is visible\n';
      f.writeAsStringSync(source);
      final outputs = await generateSuite(config, [f]);
      final first = File(outputs.single).readAsStringSync();
      await generateSuite(config, [f]);
      expect(File(outputs.single).readAsStringSync(), first);
      await generateSuite(config, [f], check: true);
      f.writeAsStringSync(source.replaceAll('"go"', '"other"'));
      await expectLater(
        generateSuite(config, [f], check: true),
        throwsA(isA<GherkinException>()),
      );
      final bad = File(p.join(root.path, 'gherkin/features/b.feature'))
        ..writeAsStringSync(
          'Feature: B\n Scenario: B\n  When I use actor "bob"\n',
        );
      await expectLater(
        generateSuite(config, [f, bad]),
        throwsA(isA<GherkinException>()),
      );
      expect(File(outputs.single).readAsStringSync(), first);
    },
  );
  test('suite order and filename disambiguation', () {
    for (final name in ['z', 'a']) {
      File(
        p.join(root.path, 'gherkin/features/$name.feature'),
      ).writeAsStringSync(
        'Feature: $name\n Scenario: s\n  When I wait 1 milliseconds',
      );
    }
    final ordered = ProjectConfig(root.path, {
      ...config.data,
      'suite': ['z.feature'],
    });
    expect(resolveFeatures(ordered, 'gherkin').map((f) => p.basename(f.path)), [
      'z.feature',
      'a.feature',
    ]);
    expect(resolveFeatures(ordered, 'a').length, 1);
  });
  test('full-suite stale check rejects orphaned generated tests', () async {
    final f = File(p.join(root.path, 'gherkin/features/a.feature'))
      ..writeAsStringSync(
        'Feature: A\n Scenario: S\n  When I wait 1 milliseconds',
      );
    await generateSuite(config, [f]);
    File(
      p.join(root.path, 'gherkin/generated/patrol/orphan_test.dart'),
    ).writeAsStringSync('// GENERATED by gherkin. old feature');
    await expectLater(
      generateSuite(config, [f], check: true),
      throwsA(isA<GherkinException>()),
    );
  });
  test(
    'recording preserves edits across action boundaries and rejects duplicate sequence',
    () {
      String e(int n, String action, Map<String, dynamic> fields) =>
          '[GHERKIN_REC] ${jsonEncode({'session': 's', 'seq': n, 'action': action, ...fields})}';
      final result = convertRecording(
        [
          e(0, 'enter_text', {'key': 'name', 'value': 'first'}),
          e(1, 'tap', {'key': 'save'}),
          e(2, 'enter_text', {'key': 'name', 'value': 'second'}),
        ].join('\n'),
        'flow',
        publicKeys: {'name'},
      );
      expect(result.feature, contains('first'));
      expect(result.feature, contains('second'));
      final duplicate = e(0, 'tap', {'key': 'save'});
      expect(
        () => convertRecording('$duplicate\n$duplicate', 'flow'),
        throwsA(isA<GherkinException>()),
      );
    },
  );
  test('Groovy flavor scope does not include unrelated build types', () {
    final block = gradleBlock(
      'productFlavors {\n dev {\n dimension "env"\n }\n}\nbuildTypes { getByName("debug") {} }',
      'productFlavors',
    );
    expect(block, contains('dev'));
    expect(block, isNot(contains('debug')));
  });
  test('dedicated actor mapping is required and Patrol rejects actors', () {
    expect(
      () => ProjectConfig(root.path, {
        ...config.data,
        'actors': {
          'a': {'device': 'one', 'connection': 'same', 'account_env': 'A'},
          'b': {'device': 'two', 'connection': 'same', 'account_env': 'B'},
        },
      }),
      throwsA(isA<GherkinException>()),
    );
    final f = parseFeature('Feature: A\n Scenario: S\n  Given I use actor "a"');
    expect(
      () => validateSupport(f, 'patrol'),
      throwsA(isA<GherkinException>()),
    );
  });
  test('VM service parsing handles machine/plain/TLS and ignores devtools', () {
    expect(
      vmUri(
        'A Dart VM Service on iPhone is available at: http://127.0.0.1:1234/token=/',
      ),
      'ws://127.0.0.1:1234/token=/ws',
    );
    expect(
      vmUri(
        '[{"event":"app.debugPort","params":{"wsUri":"wss://localhost:4567/a/ws"}}]',
      ),
      'wss://localhost:4567/a/ws',
    );
    expect(vmUri('DevTools available at http://localhost:9100'), isNull);
  });
  test(
    'CLI assertions honor exact counts and visibility; unknown format fails',
    () {
      final tree = parseCliElements(
        'Found 2 interactive element(s):\nType: Text, Key: "a", Text: "Hello", visible: true\nType: Text, Key: "b", Text: "Hello", visible: false\n',
      );
      expect(
        assertionMatches(
          parseStep('the exact text "Hello" appears exactly 1 times', 1),
          tree,
        ),
        true,
      );
      expect(
        assertionMatches(parseStep('the widget keyed "b" is absent', 1), tree),
        true,
      );
      expect(
        () => parseCliElements('not a tree'),
        throwsA(isA<GherkinException>()),
      );
    },
  );
  test(
    'multi-device runner preserves serial order with distinct drivers',
    () async {
      final timeline = <String>[];
      final a = FakeDriver(label: 'a', timeline: timeline);
      final b = FakeDriver(label: 'b', timeline: timeline);
      final actors = ProjectConfig(root.path, {
        ...config.data,
        'actors': {
          'a': {'device': 'one', 'connection': 'first', 'account_env': 'A'},
          'b': {'device': 'two', 'connection': 'second', 'account_env': 'B'},
        },
      });
      final feature = parseFeature(
        'Feature: Two\n Scenario: Serial\n  Given I use actor "a"\n  When I tap the widget keyed "first"\n  And I use actor "b"\n  And I tap the widget keyed "second"\n  And I use actor "a"\n  And I tap the widget keyed "third"',
        path: p.join(root.path, 'gherkin/features/two.feature'),
      );
      final report = await runSuite(actors, [feature], {'a': a, 'b': b});
      expect(report['failed'], 0);
      expect(timeline, ['a:first', 'b:second', 'a:third']);
      await expectLater(
        runSuite(actors, [feature], {'a': a, 'b': a}),
        throwsA(isA<GherkinException>()),
      );
    },
  );
  test(
    'runner executes keys without tree until checkpoint, stops failed scenario, saves evidence',
    () async {
      final driver = FakeDriver();
      final feature = parseFeature(
        'Feature: F\n Scenario: pass\n  When I tap the widget keyed "go"\n  Then the widget keyed "done" is visible\n Scenario: fail\n  Then the widget keyed "missing" is visible\n  When I tap the widget keyed "must_not_run"',
        path: p.join(root.path, 'gherkin/features/a.feature'),
      );
      final report = await runSuite(
        config,
        [feature],
        {'default': driver},
        assertionTimeout: Duration.zero,
      );
      expect(report['passed'], 1);
      expect(report['failed'], 1);
      expect(driver.actions, ['go']);
      expect(driver.screenshots, 2);
      expect(File(report['report'] as String).existsSync(), true);
    },
  );
}

class FakeDriver implements Driver {
  FakeDriver({this.label = '', this.timeline});
  final String label;
  final List<String>? timeline;
  final actions = <String>[];
  int screenshots = 0;
  @override
  Future<void> action(Step step) async {
    actions.add(step.args[0]);
    timeline?.add('$label:${step.args[0]}');
  }

  @override
  Future<List<Map<String, dynamic>>> elements() async => [
    {'key': 'done', 'visible': true},
  ];
  @override
  Future<void> screenshot(String path) async {
    screenshots++;
    File(path).writeAsStringSync('fixture');
  }

  @override
  Future<String> logs() async => 'fixture logs';
}
