import 'package:flutter/widgets.dart';
import 'app.dart';
import 'gherkin_harness/binding.dart';
import 'gherkin_harness/recorder.dart';

void main() {
  initializeGherkinBinding();
  final app = createApp();
  runApp(
    gherkinRecordingEnabled
        ? GherkinRecordingHarness(
            recorder: GherkinRecorder(publicTextKeys: {'name_field'}),
            child: app,
          )
        : app,
  );
}
