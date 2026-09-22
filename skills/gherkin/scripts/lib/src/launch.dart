import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'config.dart';
import 'dialect.dart';

String? vmUri(String text) {
  for (final line in const LineSplitter().convert(text).reversed) {
    String? raw;
    try {
      final v = jsonDecode(line);
      if (v is List) {
        for (final e in v) {
          if (e is Map && e['event'] == 'app.debugPort') {
            raw = e['params']?['wsUri'] as String?;
          }
        }
      }
    } catch (_) {}
    raw ??= RegExp(
      r'(?:Dart VM [Ss]ervice.*?at:|Observatory listening on)\s*(\S+)',
    ).firstMatch(line)?[1];
    if (raw == null) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !['http', 'https', 'ws', 'wss'].contains(uri.scheme) ||
        !uri.hasPort) {
      continue;
    }
    var path = uri.path;
    if (!path.endsWith('/ws')) {
      path = '${path.endsWith('/') ? path : '$path/'}ws';
    }
    return uri
        .replace(
          scheme: ['https', 'wss'].contains(uri.scheme) ? 'wss' : 'ws',
          path: path,
          query: null,
        )
        .toString();
  }
  return null;
}

List<String> launchArguments(
  ProjectConfig c, {
  bool record = false,
  String? device,
}) {
  final chosen = device ?? c.data['default_device'];
  if (chosen is! String || chosen.isEmpty) {
    throw GherkinException(
      'Select a device; set default_device or pass --device',
    );
  }
  return [
    ...c.flutter.skip(1),
    'run',
    '--machine',
    '--debug',
    '-d',
    chosen,
    '-t',
    c.entrypoint,
    if (c.data['flavor'] != null) ...['--flavor', c.data['flavor'] as String],
    for (final f in c.defines) '--dart-define-from-file=$f',
    '--dart-define=INTEGRATION_TEST=true',
    '--dart-define=GHERKIN_RECORD=$record',
    '--dart-define=GHERKIN_ENVIRONMENT=${c.environment}',
  ];
}

Future<void> launch(
  ProjectConfig c, {
  bool record = false,
  String? device,
  bool confirmProduction = false,
}) async {
  c.guard(confirmProduction: confirmProduction);
  final dir = Directory(inside(c.root, 'gherkin/evidence/logs'))
    ..createSync(recursive: true);
  final file = File(
    p.join(dir.path, 'launch-${DateTime.now().microsecondsSinceEpoch}.log'),
  );
  final sink = file.openWrite();
  final process = await Process.start(
    c.flutter.first,
    launchArguments(c, record: record, device: device),
    workingDirectory: c.appRoot,
  );
  stdout.writeln(jsonEncode({'pid': process.pid, 'log': file.path}));
  var ready = false;
  void line(String text) {
    // --machine wraps app.log in JSON. Unwrap before writing recorder events.
    String value = text;
    try {
      final events = jsonDecode(text);
      if (events is List) {
        for (final e in events) {
          if (e is Map && e['event'] == 'app.log') {
            value = e['params']['log'] as String;
          }
        }
      }
    } catch (_) {}
    sink.writeln(value);
    final uri = vmUri(text);
    if (uri != null && !ready) {
      ready = true;
      stdout.writeln(jsonEncode({'vm_service_uri': uri, 'recording': record}));
    }
  }

  final a = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(line);
  final b = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(line);
  final signal = ProcessSignal.sigint.watch().listen((_) {
    process.kill();
  });
  final timer = Timer(const Duration(minutes: 5), () {
    if (!ready) process.kill();
  });
  final code = await process.exitCode;
  timer.cancel();
  await a.cancel();
  await b.cancel();
  await signal.cancel();
  await sink.close();
  if (code != 0 || !ready) {
    throw GherkinException(
      'Launch failed or no VM service within five minutes; inspect ignored log',
    );
  }
}
