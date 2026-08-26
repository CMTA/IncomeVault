#!/usr/bin/env python3
"""Fail if any DEPLOYABLE contract exceeds the EIP-170 runtime limit.

`forge build --sizes` checks every compiled contract, including test mocks, and a mock
over the limit fails the build for no reason. `--skip` cannot be used to exclude one:
skipping any file makes the compilation partial, and the OpenZeppelin Upgrades plugin
then rejects the build-info with "is not from a full compilation", which fails every
test. So the build stays full and the size check is applied here instead, scoped to
`src/` by reading each artifact's own compilationTarget.
"""
import json, pathlib, sys

LIMIT = 24576          # EIP-170 runtime size limit
WARN = 0.9             # report anything already this close

over, near, checked = [], [], 0
for art in pathlib.Path('out').rglob('*.json'):
    try:
        j = json.loads(art.read_text())
    except Exception:
        continue
    targets = j.get('metadata', {}).get('settings', {}).get('compilationTarget', {})
    src = next((p for p in targets if p.startswith('src/')), None)
    if not src:
        continue
    obj = (j.get('deployedBytecode') or {}).get('object', '')
    size = max(0, (len(obj) - 2) // 2)
    if size == 0:
        continue                      # interface or fully abstract
    checked += 1
    name = targets[src]
    if size > LIMIT:
        over.append((name, src, size))
    elif size > LIMIT * WARN:
        near.append((name, src, size))

for name, src, size in sorted(near, key=lambda x: -x[2]):
    print(f"  NOTE: {name} is {size} bytes, {LIMIT - size} under the EIP-170 limit ({src})")

# Fail loudly rather than pass silently. Every filter above can legitimately empty the
# set, so "nothing to report" and "nothing was looked at" print the same reassuring line.
# If `metadata` ever stops being emitted, `compilationTarget` disappears, every contract
# is skipped, and this check would otherwise report success having measured nothing.
if checked == 0:
    print("  EIP-170: measured NOTHING — no deployable contract found under src/.")
    print("    Either the build did not run, or the artifacts carry no `metadata."
          "settings.compilationTarget` to scope by.")
    sys.exit(1)

if over:
    print(f"  EIP-170: {len(over)} deployable contract(s) exceed {LIMIT} bytes:")
    for name, src, size in sorted(over, key=lambda x: -x[2]):
        print(f"    {name}  {size}  (+{size - LIMIT})  {src}")
    sys.exit(1)

print(f"  EIP-170: {checked} deployable contract(s) in src/, all within {LIMIT} bytes")
