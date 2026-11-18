#!/usr/bin/env python3
"""Check the cloud configuration in a built Release app, not its source files."""

import argparse
import json
import plistlib
import re
from pathlib import Path


DEVELOPMENT_PROJECT = "xufledziawaapvrifbfv"


def validate(info, project_ref):
    errors = []
    if not re.fullmatch(r"[a-z0-9]{20}", project_ref) or project_ref == DEVELOPMENT_PROJECT:
        errors.append("Expected project must be a production Supabase project.")
    if info.get("CFBundleIdentifier") != "com.farrierflow.yusufcan.FarrierFlow":
        errors.append("Bundle identifier does not match FarrierFlow.")
    if info.get("SUPABASE_URL") != f"https://{project_ref}.supabase.co":
        errors.append("Built app does not use the expected production endpoint.")
    key = info.get("SUPABASE_PUBLISHABLE_KEY", "")
    if not isinstance(key, str) or not re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{16,}", key):
        errors.append("Built app must contain a resolved public publishable key.")
    if info.get("SUPABASE_CLOUD_DELETION_ENABLED") is not True:
        errors.append("Cloud-account deletion is not enabled in the built app.")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Path to the built FarrierFlow.app")
    parser.add_argument("--project-ref", required=True, help="Verified production project reference")
    args = parser.parse_args()
    try:
        with (args.app / "Info.plist").open("rb") as source:
            info = plistlib.load(source)
        errors = validate(info, args.project_ref)
    except (OSError, plistlib.InvalidFileException, ValueError) as error:
        parser.exit(2, f"Cannot inspect built app: {error}\n")
    print(json.dumps({"configured": not errors, "errors": errors}, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
