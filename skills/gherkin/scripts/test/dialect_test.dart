import 'package:test/test.dart';
import 'package:gherkin_tools/src/dialect.dart';

void main() {
  const valid = '''@smoke
Feature: Login
 Background:
  Given the app is running in the integration environment
  And I am logged out
 Scenario: Login
  When I tap the widget keyed "login"
  And I enter "5551234567" into the widget keyed "phone"
  Then the widget keyed "otp" is visible
''';
  test('parses background, tags and typed steps', () {
    final f = parseFeature(valid);
    expect(f.background.length, 2);
    expect(f.scenarios.single.tags, ['smoke']);
    expect(f.scenarios.single.steps.last.kind, 'assert_key_visible');
  });
  test('rejects arbitrary prose, outlines, ambiguous structures', () {
    for (final src in [
      valid.replaceFirst(
        'When I tap the widget keyed "login"',
        'When do login',
      ),
      valid.replaceFirst('Scenario:', 'Scenario Outline:'),
      valid.replaceFirst('Given the app', 'And the app'),
      '$valid\n | table |',
      valid.replaceFirst(
        'Then the widget keyed "otp" is visible',
        'Then I tap the widget keyed "otp"',
      ),
    ]) {
      expect(() => parseFeature(src), throwsA(isA<GherkinException>()));
    }
  });
  test('support and sensitive input fail closed', () {
    expect(
      parseStep('I press the device home button', 1).support,
      Support.patrol,
    );
    expect(
      () => parseStep('I wait 30001 milliseconds', 1),
      throwsA(isA<GherkinException>()),
    );
    expect(
      () => parseStep('I enter "123456" into the widget keyed "otp"', 1),
      throwsA(isA<GherkinException>()),
    );
    expect(
      parseStep(
        r'I enter "${env:OTP}" into the widget keyed "otp"',
        1,
      ).args.first,
      r'${env:OTP}',
    );
  });
}
