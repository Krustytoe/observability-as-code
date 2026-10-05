#!/usr/bin/env python3
"""Policy checks for rendered dashboards (stdlib only).

Fails when a dashboard:
  - is missing a uid, or the uid is over Grafana's 40-char limit, or uids collide
  - references a datasource by a hard-coded uid instead of the $datasource variable
  - is editable (the repo is the source of truth; UI edits get overwritten)
"""
import json
import sys
from pathlib import Path


def walk_datasources(node, path="$"):
    if isinstance(node, dict):
        ds = node.get("datasource")
        if isinstance(ds, dict) and "uid" in ds and not str(ds["uid"]).startswith("$"):
            yield f"{path}.datasource.uid={ds['uid']!r}"
        for key, value in node.items():
            yield from walk_datasources(value, f"{path}.{key}")
    elif isinstance(node, list):
        for i, item in enumerate(node):
            yield from walk_datasources(item, f"{path}[{i}]")


def main(build_dir: str) -> int:
    files = sorted(Path(build_dir).glob("*.json"))
    if not files:
        print(f"no dashboards found in {build_dir}", file=sys.stderr)
        return 1

    errors, uids = [], {}
    for f in files:
        dash = json.loads(f.read_text())
        uid = dash.get("uid")
        if not uid:
            errors.append(f"{f.name}: missing uid")
        elif len(uid) > 40:
            errors.append(f"{f.name}: uid {uid!r} exceeds 40 chars")
        elif uid in uids:
            errors.append(f"{f.name}: uid {uid!r} duplicates {uids[uid]}")
        else:
            uids[uid] = f.name
        if dash.get("editable", True):
            errors.append(f"{f.name}: editable must be false")
        errors.extend(f"{f.name}: hard-coded datasource {hit}" for hit in walk_datasources(dash))
        print(f"checked {f.name}: uid={uid} panels={len(dash.get('panels', []))}")

    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/dashboards"))
