#!/usr/bin/env python3
"""
Terraform external data source.

Find the latest complete Japan East RecoverySet containing:
- DiskRole=OS
- DiskRole=DATA-LUN-0
- ManagedBy=SnapshotDRDemo
- CopyStage=Target
- SourceVM=<source_vm_name>
"""

from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from typing import Any


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def run_az(args: list[str]) -> Any:
    command = ["az", *args, "--output", "json", "--only-show-errors"]
    try:
        completed = subprocess.run(
            command,
            check=True,
            text=True,
            capture_output=True,
        )
    except FileNotFoundError:
        fail("Azure CLI 'az' was not found in PATH.")
    except subprocess.CalledProcessError as exc:
        fail(f"Azure CLI failed:\n{exc.stderr}")

    return json.loads(completed.stdout)


def main() -> None:
    try:
        query = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        fail(f"Invalid external data query: {exc}")

    subscription_id = query["subscription_id"]
    resource_group = query["resource_group_name"]
    source_vm = query["source_vm_name"]

    subprocess.run(
        ["az", "account", "set", "--subscription", subscription_id],
        check=True,
        text=True,
        capture_output=True,
    )

    snapshots = run_az([
        "snapshot",
        "list",
        "--resource-group",
        resource_group,
    ])

    sets: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)

    for snapshot in snapshots:
        tags = snapshot.get("tags") or {}

        if tags.get("ManagedBy") != "SnapshotDRDemo":
            continue
        if tags.get("CopyStage") != "Target":
            continue
        if tags.get("SourceVM") != source_vm:
            continue

        recovery_set = tags.get("RecoverySet")
        role = tags.get("DiskRole")

        if not recovery_set or not role:
            continue

        state = snapshot.get("provisioningState")
        completion = snapshot.get("completionPercent")

        # Some CLI/API combinations omit completionPercent after successful completion.
        complete = state == "Succeeded" and (
            completion in (None, 100, 100.0, "100", "100.0")
        )

        if complete:
            sets[recovery_set][role] = snapshot

    complete_sets = [
        recovery_set
        for recovery_set, role_map in sets.items()
        if "OS" in role_map and "DATA-LUN-0" in role_map
    ]

    if not complete_sets:
        fail(
            "No complete target RecoverySet was found. "
            "Run the Automation snapshot-copy runbook and wait for completion."
        )

    latest = sorted(complete_sets)[-1]
    role_map = sets[latest]

    result = {
        "recovery_set": latest,
        "os_snapshot_id": role_map["OS"]["id"],
        "data_snapshot_id": role_map["DATA-LUN-0"]["id"],
        "os_snapshot_name": role_map["OS"]["name"],
        "data_snapshot_name": role_map["DATA-LUN-0"]["name"],
    }

    json.dump(result, sys.stdout)


if __name__ == "__main__":
    main()
