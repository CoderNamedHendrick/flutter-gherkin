# Publishing flutter-gherkin

The repository is [CoderNamedHendrick/flutter-gherkin](https://github.com/CoderNamedHendrick/flutter-gherkin).
The distribution is **flutter-gherkin**; the installed skill remains **gherkin**.
The current release version is **0.1.1**.

This is an Agent Skills repository, not an npm or pub.dev package. Users install with:

```sh
npx skills add CoderNamedHendrick/flutter-gherkin --skill gherkin -a universal
```

## Prepare a release

Update `skills/gherkin/SKILL.md` metadata.version and
`skills/gherkin/scripts/pubspec.yaml` version together. Keep the helper lockfile:
installed helpers use `dart pub get --enforce-lockfile`.

```sh
dart tooling/verify.dart
python3 -m unittest discover -s tooling -p 'test_android_smoke.py'
uvx --from skills-ref agentskills validate skills/gherkin
python3 tooling/prepare_release.py
```

Run native smoke on selected devices and record actual results in [VALIDATION.md](VALIDATION.md).
The release builder creates a deterministic ZIP, SHA-256 checksum and file manifest
under ignored `dist/`, excluding caches, fixtures, builds and evidence. These are
optional GitHub release assets; Skills CLI installs use the repository source.

## Publish an authorized release

Review the diff and commit the verified source, then push to `main`. Create the
release against that exact commit, with its corresponding assets and release notes:

```sh
git push origin main
gh release create v0.1.1 dist/flutter-gherkin-0.1.1.zip dist/flutter-gherkin-0.1.1.zip.sha256 dist/flutter-gherkin-0.1.1.manifest.json --repo CoderNamedHendrick/flutter-gherkin --target "$(git rev-parse HEAD)" --title "flutter-gherkin 0.1.1" --notes-file /path/to/release-notes.md
```

Verify the public release and install the tagged skill into a clean destination.
Run locked dependency setup, helper analysis and tests from the installed copy.
There is no separate skills.sh upload; listing/discovery follows Skills CLI usage
and is not guaranteed by creating a GitHub release.
