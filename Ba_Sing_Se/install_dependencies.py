#!/usr/bin/env python3
"""Install missing Python dependencies declared in requirements.yaml.

The manifest is JSON-compatible YAML, so this bootstrap program can read it
with the Python standard library before PyYAML itself is installed.
"""

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Install observation-downloader Python dependencies.")
    parser.add_argument("--requirements", type=Path, default=Path(__file__).with_name("requirements.yaml"),
                        help="Dependency manifest (default: requirements.yaml beside this script)")
    parser.add_argument("--upgrade", action="store_true", help="Ask pip to upgrade installed packages too")
    parser.add_argument("--dry-run", action="store_true", help="Show packages that would be installed")
    return parser.parse_args()


def load_manifest(path):
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Cannot read JSON-compatible YAML manifest {path}: {error}") from error
    packages = manifest.get("packages")
    if not isinstance(packages, list):
        raise ValueError("Manifest must contain a packages list")
    return packages


def main():
    args = parse_args()
    missing = [package for package in load_manifest(args.requirements)
               if not importlib.util.find_spec(package["import_name"])]
    if not missing and not args.upgrade:
        print("All Python dependencies are already installed.")
        return 0
    targets = [package["requirement"] for package in (load_manifest(args.requirements) if args.upgrade else missing)]
    command = [sys.executable, "-m", "pip", "install"]
    if args.upgrade:
        command.append("--upgrade")
    command.extend(targets)
    print("Would run:" if args.dry_run else "Running:", " ".join(command))
    if args.dry_run:
        return 0
    return subprocess.run(command, check=False).returncode


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(2)
