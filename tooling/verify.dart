import 'dart:io';

Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent.path;
  Future<void> run(String directory, String command, List<String> args) async {
    final process = await Process.start(
      command,
      args,
      workingDirectory: directory,
      mode: ProcessStartMode.inheritStdio,
    );
    final status = await process.exitCode;
    if (status != 0) {
      exitCode = status;
      throw StateError('$command ${args.join(' ')} failed');
    }
  }

  final scripts = '$root/skills/gherkin/scripts';
  await run(scripts, 'dart', ['pub', 'get', '--enforce-lockfile']);
  await run(scripts, 'dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'bin',
    'lib',
    'test',
  ]);
  await run(scripts, 'dart', ['analyze']);
  await run(scripts, 'dart', ['test']);
  final app = '$root/test/fixtures/minimal_app';
  await run(app, 'flutter', ['pub', 'get', '--enforce-lockfile']);
  await run(app, 'flutter', ['analyze']);
  await run(app, 'flutter', ['test']);
  await run(app, 'flutter', [
    'test',
    '--dart-define=INTEGRATION_TEST=true',
    '--dart-define=GHERKIN_RECORD=true',
  ]);
  await run(scripts, 'dart', [
    'run',
    'bin/gherkin.dart',
    'check-generated',
    'gherkin',
    '--root',
    app,
  ]);
  stdout.writeln(
    'Static and fixture checks passed. Native smoke requires an explicitly selected device.',
  );
}
