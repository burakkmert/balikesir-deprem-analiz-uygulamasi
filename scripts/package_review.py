#!/usr/bin/env python3
"""Package a Flutter source review without running builds or changing sources.

Example (run from the Flutter project root):
    python scripts/package_review.py --project . --step 7 \
        --output-dir "C:\\Users\\Monster\\Desktop\\afet-analiz-backups" --open
Uses only the Python standard library. Requires Python 3.9+.
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid
from datetime import datetime, timezone
import zipfile

SOURCE_DIRS = ("lib", "scripts", "test", "integration_test", "assets/data", "docs", "licenses")
ROOT_FILES = ("pubspec.yaml", "pubspec.lock", "analysis_options.yaml")
EXCLUDED_DIRS = {".git", ".dart_tool", ".gradle", "__pycache__", "build",
                 ".venv", "venv", "node_modules", ".idea", ".vscode"}
EXCLUDED_FILES = (
    ".env*", "local.properties", "key.properties", "*.jks", "*.keystore",
    "*.pem", "*.key", "*.p12", "*.pfx", "*.pyc", "*.pyo", "*.zip",
    "*.apk", "*.aab", "*.log.lock", "credentials*.json", "*service-account*.json",
)


def is_link(path: Path) -> bool:
    return path.is_symlink() or bool(getattr(path, "is_junction", lambda: False)())


def excluded(path: Path, root: Path) -> bool:
    relative = path.relative_to(root)
    if any(part.lower() in EXCLUDED_DIRS for part in relative.parts[:-1]):
        return True
    return any(fnmatch.fnmatch(path.name.lower(), pattern) for pattern in EXCLUDED_FILES)


def collect_files(root: Path) -> dict[str, Path]:
    result: dict[str, Path] = {}

    def add(path: Path) -> None:
        if is_link(path) or not path.is_file() or excluded(path, root):
            return
        resolved = path.resolve(strict=True)
        if root not in resolved.parents:
            raise ValueError(f"Source resolves outside project: {path}")
        result[path.relative_to(root).as_posix()] = path

    for filename in ROOT_FILES:
        add(root / filename)
    for folder in SOURCE_DIRS:
        start = root / folder
        if not start.is_dir() or is_link(start):
            continue
        for current, directories, filenames in os.walk(start, followlinks=False):
            current_path = Path(current)
            directories[:] = sorted(d for d in directories
                                     if d.lower() not in EXCLUDED_DIRS
                                     and not is_link(current_path / d))
            for filename in sorted(filenames):
                add(current_path / filename)
    for path in root.iterdir():
        if path.is_file() and path.name.lower().startswith(("license", "licence", "notice", "third_party")):
            add(path)
    return dict(sorted(result.items()))


def digest_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def create_archive(project: Path, destination: Path, step: int) -> dict:
    root = project.expanduser().resolve(strict=True)
    if not (root / "pubspec.yaml").is_file() or not (root / "lib").is_dir():
        raise ValueError("Not a Flutter project root: pubspec.yaml and lib/ are required.")
    spec = (root / "pubspec.yaml").read_text(encoding="utf-8-sig")
    match = re.search(r"(?m)^name:\s*['\"]?([a-zA-Z0-9_]+)", spec)
    project_name = match.group(1) if match else "unknown"
    if project_name != "afet_analiz":
        raise ValueError(f"Expected pubspec name afet_analiz; found {project_name!r}. Check --project.")
    destination = destination.expanduser().resolve()
    if destination == root or root in destination.parents:
        raise ValueError("The output directory must be outside the project.")
    files = collect_files(root)
    if not any(name.startswith("lib/") and name.endswith(".dart") for name in files):
        raise ValueError("No Dart source files found under lib/.")
    required = ["pubspec.lock", "analysis_options.yaml", "docs/repair_progress.json",
                f"docs/step{step}_verification.log"]
    if step == 7:
        required.append("docs/afad_contract_check.json")
    missing = [name for name in required if name not in files]
    for prefix in ("scripts/", "test/", "assets/data/"):
        if not any(name.startswith(prefix) for name in files):
            missing.append(prefix + " (no eligible files)")
    destination.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_UTC")
    output = destination / f"step{step}_review_{stamp}_{uuid.uuid4().hex[:8]}.zip"
    before = {name: digest_file(path) for name, path in files.items()}
    created = False
    try:
        with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            created = True
            for name, path in files.items():
                archive.write(path, arcname=name)
        with zipfile.ZipFile(output, "r") as archive:
            if archive.testzip() is not None:
                raise ValueError("Archive integrity check failed.")
            if sorted(archive.namelist()) != list(files):
                raise ValueError("Archive file list differs from the source selection.")
            for name, path in files.items():
                packed_hash = hashlib.sha256(archive.read(name)).hexdigest()
                if packed_hash != before[name] or packed_hash != digest_file(path):
                    raise ValueError(f"Source changed during packaging or hash mismatch: {name}")
        if list(collect_files(root)) != list(files):
            raise ValueError("Source file list changed during packaging. Retry after saving files.")
        return {
            "status": "archive_verified" if not missing else "archive_verified_with_missing_inputs",
            "project": str(root), "archive": str(output),
            "size_bytes": output.stat().st_size, "file_count": len(files),
            "archive_sha256": digest_file(output), "zip_integrity": "PASS",
            "included_sources_sha256_match": f"{len(files)}/{len(files)}",
            "missing_expected_inputs": missing,
            "tests_or_builds_run_by_this_script": False,
            "notice": "Hashes verify packaging, not code correctness, test results, or file contents for secrets.",
        }
    except Exception:
        # Remove only the new incomplete archive; never remove source files.
        if created and output.is_file():
            output.unlink()
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--step", type=int, choices=range(1, 10), required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--open", action="store_true", dest="open_explorer")
    args = parser.parse_args()
    try:
        report = create_archive(args.project, args.output_dir, args.step)
        if args.open_explorer and os.name == "nt":
            try:
                subprocess.Popen(["explorer.exe", f"/select,{report['archive']}"])
                report["explorer"] = "Selection request sent; visual confirmation not performed."
            except OSError as exc:
                report["explorer"] = f"Could not open Explorer: {exc}"
        print(json.dumps(report, ensure_ascii=True, indent=2))
        return 0
    except Exception as exc:
        print(f"PACKAGING FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
