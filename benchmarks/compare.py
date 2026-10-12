#!/usr/bin/env python3
"""Compare release benchmark JSONL by name, including allocations and checksums."""
import json
import sys
from pathlib import Path


def read(filename):
    return {row["name"]: row for row in map(json.loads, Path(filename).read_text().splitlines())}


baseline = read(sys.argv[1])
contender = read(sys.argv[2])
regressions = []
rows = ["| Case | Base ns/op | PR ns/op | Time ratio | Base bytes | PR bytes |",
        "|---|---:|---:|---:|---:|---:|"]
for name, new in contender.items():
    old = baseline.get(name)
    if old is None:
        rows.append(f"| {name} (new API) | — | {new['ns']:.1f} | — | — | {new['bytes']:.1f} |")
        continue
    if old["checksum"] != new["checksum"]:
        raise SystemExit(f"Result checksum differs for {name}")
    ratio = new["ns"] / old["ns"]
    rows.append(f"| {name} | {old['ns']:.1f} | {new['ns']:.1f} | {ratio:.3f} | {old['bytes']:.1f} | {new['bytes']:.1f} |")
    # Microbenchmarks are noisy; flag changes for inspection rather than using
    # one shared runner measurement as a deterministic release gate.
    if ratio > 1.15 or new["bytes"] > old["bytes"] * 1.05 + 1:
        regressions.append(name)
missing = baseline.keys() - contender.keys()
if missing:
    raise SystemExit(f"Missing benchmark cases: {', '.join(sorted(missing))}")
rows.append("")
rows.append("Review flagged cases (>15% slower or increased allocations): " + ", ".join(regressions)
            if regressions else "No cases exceeded the time/allocation review thresholds.")
print("\n".join(rows))
