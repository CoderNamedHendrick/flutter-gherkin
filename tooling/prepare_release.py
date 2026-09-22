#!/usr/bin/env python3
"""Build a deterministic, source-only flutter-gherkin release. Does not publish."""

import hashlib
import json
from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parent.parent
EXCLUDED = {".dart_tool", "build", "__pycache__", ".DS_Store"}


def main():
    skills = list((ROOT / "skills").glob("*/SKILL.md"))
    if len(skills) != 1:
        raise ValueError("This release must contain exactly one skill")
    SKILL = skills[0].parent
    text = (SKILL / "SKILL.md").read_text()
    if not re.search(rf"^name: {re.escape(SKILL.name)}$", text, re.MULTILINE):
        raise ValueError("Skill directory and frontmatter name differ")
    version = re.search(r'^  version: "(\d+\.\d+\.\d+)"$', text, re.MULTILINE)
    if not version:
        raise ValueError("SKILL.md needs a quoted semantic metadata.version")
    version = version[1]
    if not re.search(rf"^version: {re.escape(version)}$",
                     (SKILL / "scripts/pubspec.yaml").read_text(), re.MULTILINE):
        raise ValueError("Skill and Dart helper versions differ")
    if (SKILL / "LICENSE").read_bytes() != (ROOT / "LICENSE").read_bytes():
        raise ValueError("Installed skill LICENSE must match repository LICENSE")

    # Explicit source types and directories keep caches, logs and local files out.
    sources = [SKILL / "SKILL.md", SKILL / "LICENSE"]
    for folder, extensions in [("references", {".md"}), ("assets", {".dart"}),
                               ("scripts", {".dart", ".yaml", ".lock"})]:
        for source in sorted((SKILL / folder).rglob("*")):
            relative = source.relative_to(SKILL)
            if any(part in EXCLUDED for part in relative.parts):
                continue
            if source.is_symlink():
                raise ValueError(f"Unexpected symlink: {relative}")
            if source.is_file():
                if source.suffix not in extensions:
                    raise ValueError(f"Unreviewed release file: {relative}")
                sources.append(source)

    output = ROOT / "dist"
    output.mkdir(exist_ok=True)
    archive = output / f"flutter-gherkin-{version}.zip"
    manifest = []
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for source in sorted(sources):
            data = source.read_bytes()
            name = SKILL.name + "/" + source.relative_to(SKILL).as_posix()
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            package.writestr(info, data)
            manifest.append(dict(path=name, bytes=len(data),
                                 sha256=hashlib.sha256(data).hexdigest()))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
    archive.with_suffix(".manifest.json").write_text(
        json.dumps(dict(name="flutter-gherkin", skill=SKILL.name, version=version,
                        files=manifest), indent=2) + "\n"
    )
    print(json.dumps(dict(archive=str(archive), sha256=digest,
                          files=len(manifest), bytes=archive.stat().st_size), indent=2))


if __name__ == "__main__":
    main()
