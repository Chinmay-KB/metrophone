#!/usr/bin/env python3
"""Require a Flutter pubspec version to advance beyond a base revision."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import NamedTuple


VERSION_LINE = re.compile(
    r"^version\s*:\s*['\"]?(?P<version>\d+\.\d+\.\d+\+\d+)['\"]?\s*$",
    re.MULTILINE,
)


class AppVersion(NamedTuple):
    major: int
    minor: int
    patch: int
    build: int

    @property
    def release(self) -> tuple[int, int, int]:
        return self.major, self.minor, self.patch

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}+{self.build}"


def parse_pubspec(contents: str, source: str) -> AppVersion:
    match = VERSION_LINE.search(contents)
    if match is None:
        raise ValueError(
            f"{source} must contain a numeric version in MAJOR.MINOR.PATCH+BUILD format"
        )
    release, build = match.group("version").split("+", maxsplit=1)
    major, minor, patch = (int(part) for part in release.split("."))
    return AppVersion(major, minor, patch, int(build))


def verify_versions(head: AppVersion, base: AppVersion) -> None:
    failures: list[str] = []
    if head.release <= base.release:
        failures.append(
            f"semantic version {head.major}.{head.minor}.{head.patch} must be greater "
            f"than {base.major}.{base.minor}.{base.patch}"
        )
    if head.build <= base.build:
        failures.append(
            f"Android build number {head.build} must be greater than {base.build}"
        )
    if failures:
        raise ValueError("; ".join(failures))


def read_base_pubspec(base_ref: str) -> str:
    completed = subprocess.run(
        ["git", "show", f"{base_ref}:pubspec.yaml"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or "git show failed"
        raise ValueError(f"could not read pubspec.yaml from {base_ref}: {detail}")
    return completed.stdout


def emit_error(message: str) -> None:
    if os.environ.get("GITHUB_ACTIONS") == "true":
        escaped = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::error title=Version must increase::{escaped}")
    print(f"Version check failed: {message}", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--head-file", default="pubspec.yaml")
    base = parser.add_mutually_exclusive_group(required=True)
    base.add_argument("--base-ref")
    base.add_argument("--base-file")
    args = parser.parse_args(argv)

    try:
        head_contents = Path(args.head_file).read_text(encoding="utf-8")
        if args.base_file:
            base_contents = Path(args.base_file).read_text(encoding="utf-8")
            base_source = args.base_file
        else:
            base_contents = read_base_pubspec(args.base_ref)
            base_source = f"{args.base_ref}:pubspec.yaml"

        head_version = parse_pubspec(head_contents, args.head_file)
        base_version = parse_pubspec(base_contents, base_source)
        verify_versions(head_version, base_version)
    except (OSError, ValueError) as error:
        emit_error(str(error))
        return 1

    print(f"Version check passed: {head_version} > {base_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
