#!/usr/bin/env python3
"""Run the Android fixture suite, retaining native verdicts and full system logs.

Requires an explicitly selected, already booted emulator. Never retries a failure,
wipes a device, changes dependencies, or treats Dart-level success as native PASS.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "test/fixtures/minimal_app"


def native_verdict(exit_code, reports, expected_tests):
    counts = dict(tests=0, failures=0, errors=0, skipped=0)
    for report in reports:
        suite = ET.parse(report).getroot()
        if suite.tag != "testsuite":
            raise ValueError(f"Unexpected native report format: {report.name}")
        for key in counts:
            counts[key] += int(suite.get(key, "0"))
    passed = (
        exit_code == 0
        and counts["tests"] == expected_tests
        and counts["failures"] == counts["errors"] == counts["skipped"] == 0
    )
    return dict(passed=passed, exit_code=exit_code, **counts)


def stop(process):
    if process.poll() is not None:
        return
    if os.name == "posix":
        os.killpg(process.pid, signal.SIGTERM)
    else:
        process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        if os.name == "posix":
            os.killpg(process.pid, signal.SIGKILL)
        else:
            process.kill()
        process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True, help="Selected emulator serial")
    parser.add_argument("--adb", default=shutil.which("adb") or "adb")
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--expected-tests", type=int, default=4)
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    if min(args.repeat, args.expected_tests, args.timeout) < 1:
        parser.error("repeat, expected-tests and timeout must be positive")
    if not args.device.startswith("emulator-"):
        parser.error("This fixture smoke tool is restricted to disposable emulators")

    adb = [args.adb, "-s", args.device]

    def shell(*command):
        return subprocess.check_output(
            [*adb, "shell", *command], text=True, timeout=15
        ).strip()

    if shell("getprop", "sys.boot_completed") != "1":
        raise RuntimeError("Selected emulator has not completed boot")
    # The boot property alone does not prove that Package Manager is responsive.
    if not shell("pm", "path", "android").startswith("package:"):
        raise RuntimeError("Selected emulator's Package Manager is not ready")

    output = ROOT / ".test-work" / f"android-smoke-{time.time_ns()}"
    output.mkdir(parents=True)
    metadata = {
        "device": args.device,
        "fingerprint": shell("getprop", "ro.build.fingerprint"),
        "api": shell("getprop", "ro.build.version.sdk"),
        "storage": shell("df", "-h", "/data"),
    }
    (output / "device.json").write_text(json.dumps(metadata, indent=2) + "\n")
    command = [
        "dart", "run", "patrol_cli:main", "test", "-d", args.device,
        "--dart-define=GHERKIN_ENVIRONMENT=local", "--verbose",
    ]
    print(f"Native smoke evidence: {output}", flush=True)
    for index in range(1, args.repeat + 1):
        run = output / f"run-{index}"
        run.mkdir()
        started = time.time_ns()
        with (run / "logcat.txt").open("w") as logcat_file, (
            run / "patrol.log"
        ).open("w") as patrol_file:
            # Capture all buffers, not just Flutter or the app PID: the dead
            # UiAutomation Binder can belong to the separate am/shell process.
            logcat = subprocess.Popen(
                [*adb, "logcat", "-b", "all", "-v", "threadtime", "-T", "1"],
                stdout=logcat_file, stderr=subprocess.STDOUT, start_new_session=True,
            )
            patrol = None
            try:
                patrol = subprocess.Popen(
                    command, cwd=APP, stdout=patrol_file,
                    stderr=subprocess.STDOUT, start_new_session=True,
                )
                try:
                    code = patrol.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    stop(patrol)
                    code = 124
            finally:
                if patrol is not None:
                    stop(patrol)
                capture_exit = logcat.poll()
                stop(logcat)

        results = APP / "build/app/outputs/androidTest-results/connected/debug"
        reports = []
        for report in results.glob("TEST-*.xml"):
            if report.stat().st_mtime_ns >= started:
                reports.append(Path(shutil.copy2(report, run / report.name)))
        verdict = native_verdict(code, reports, args.expected_tests)
        verdict["logcat_ended_early"] = capture_exit is not None
        if capture_exit is not None:
            verdict["passed"] = False
        (run / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
        print(f"Run {index}: {json.dumps(verdict)}", flush=True)
        if not verdict["passed"]:
            return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, ET.ParseError) as error:
        print(f"Android smoke failed: {error}", file=sys.stderr)
        sys.exit(1)
