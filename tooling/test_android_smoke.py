import tempfile
from pathlib import Path
import unittest

from android_smoke import native_verdict


class NativeVerdictTest(unittest.TestCase):
    def report(self, directory, **attributes):
        values = dict(tests=4, failures=0, errors=0, skipped=0)
        values.update(attributes)
        report = Path(directory) / "TEST-fixture.xml"
        attrs = " ".join(f'{key}="{value}"' for key, value in values.items())
        report.write_text(f"<testsuite {attrs}/>")
        return [report]

    def test_requires_native_process_success_even_when_all_tests_passed(self):
        with tempfile.TemporaryDirectory() as directory:
            reports = self.report(directory)
            self.assertTrue(native_verdict(0, reports, 4)["passed"])
            self.assertFalse(native_verdict(1, reports, 4)["passed"])
            self.assertFalse(native_verdict(124, reports, 4)["passed"])

    def test_rejects_missing_incomplete_failed_or_skipped_native_results(self):
        self.assertFalse(native_verdict(0, [], 4)["passed"])
        with tempfile.TemporaryDirectory() as directory:
            for changes in [dict(tests=0), dict(tests=3), dict(failures=1),
                            dict(errors=1), dict(skipped=1)]:
                with self.subTest(changes=changes):
                    reports = self.report(directory, **changes)
                    self.assertFalse(native_verdict(0, reports, 4)["passed"])


if __name__ == "__main__":
    unittest.main()
