# Publishing flutter-gherkin

The distribution/repository name is **flutter-gherkin**. The single installed skill
remains **gherkin**, invoked as `$gherkin` or through natural-language requests.
The first prepared release is **0.1.0**.

This uses [skills.sh and the Skills CLI](https://skills.sh/docs/faq), which install
skills from GitHub repositories. There is no npm package to publish and no separate
skills.sh upload command. Listing follows installations reported by the Skills CLI;
publication does not guarantee immediate ranking or discovery.

## Prepared destination

The proposed public source is `CoderNamedHendrick/flutter-gherkin`, using the currently
authenticated GitHub account. No repository was created or pushed during preparation.
Change the owner below if publishing through an organization instead.

After publication, the install command will be:

```sh
npx skills add CoderNamedHendrick/flutter-gherkin --skill gherkin -a universal
```

## Release contents and checks

`skills/gherkin/` contains the complete installable skill, including its MIT license,
version metadata, references, harness assets and locked Dart helper package. Keep the
helper `pubspec.lock`; users run `dart pub get --enforce-lockfile` after installing.
The helper package stays `publish_to: none` because it ships inside the skill.

```sh
dart tooling/verify.dart
python3 -m unittest discover -s tooling -p 'test_android_smoke.py'
skills-ref validate skills/gherkin
python3 tooling/prepare_release.py
```

`skills-ref` is the official [Agent Skills reference validator](https://github.com/agentskills/agentskills/tree/main/skills-ref).
Mobile smoke checks require selected devices; see [validation results](VALIDATION.md).
Version 0.1.0 has verified iOS and Android fixture runs, with human recording acceptance,
live multi-device execution and other documented coverage limits still outstanding.

The release builder writes these ignored artifacts:

- `dist/flutter-gherkin-0.1.0.zip`: the installable `gherkin/` directory.
- `dist/flutter-gherkin-0.1.0.zip.sha256`: archive checksum.
- `dist/flutter-gherkin-0.1.0.manifest.json`: file inventory and per-file hashes.

The archive excludes SDK caches, builds, fixtures, evidence, local device settings and
repository development tooling. Repeated builds from identical inputs produce identical
bytes. Version changes must update both SKILL.md metadata and scripts/pubspec.yaml.
The archive is an optional release attachment; normal `npx skills add` installs from
the repository's `skills/gherkin/` directory.

## Publish when authorized

The working directory is not yet a Git repository. Review the source files and ignored
files before making the initial commit. The steps below are instructions only and were
not executed during preparation:

```sh
git init -b main
git add README.md LICENSE VALIDATION.md PUBLISHING.md .gitignore skills test tooling
git diff --cached --stat
# Review staged contents before continuing.
git commit -m "Prepare flutter-gherkin 0.1.0"
gh repo create CoderNamedHendrick/flutter-gherkin --public --source . --remote origin --push
```

Test the public install in an empty temporary project using the command above, then
verify the installed helper's locked setup and a feature validation. Once that succeeds,
an optional GitHub release can attach the prepared ZIP, checksum and manifest:

```sh
gh release create v0.1.0 dist/flutter-gherkin-0.1.0.zip dist/flutter-gherkin-0.1.0.zip.sha256 dist/flutter-gherkin-0.1.0.manifest.json --repo CoderNamedHendrick/flutter-gherkin --title "flutter-gherkin 0.1.0" --notes "Initial universal gherkin skill. See README and VALIDATION.md for setup and verified coverage."
```

Public GitHub installation and skills.sh listing can only be checked after publication.
