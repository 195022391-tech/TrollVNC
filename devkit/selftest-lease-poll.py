#!/usr/bin/env python3
"""Source-level checks: fast poll must not shrink the post-connect disconnect budget."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
server = (ROOT / "src" / "trollvncserver.mm").read_text(encoding="utf-8", errors="replace")
lease = (ROOT / "src" / "LeaseGate.mm").read_text(encoding="utf-8", errors="replace")

errs = []

def need(cond, msg):
    if not cond:
        errs.append(msg)

need(
    re.search(
        r"CFTimeInterval\s+interval\s*=\s*TVLeasePendingPair\(\)\s*\?\s*2\.0\s*:\s*60\.0",
        server,
    ),
    "tvArmLeaseTimer must use PendingPair ? 2 : 60 only",
)
m = re.search(r"static void tvArmLeaseTimer\(void\) \{.*?^\}", server, re.M | re.S)
need(m is not None, "tvArmLeaseTimer not found")
if m:
    need("!gVncStarted" not in m.group(0), "tvArmLeaseTimer must not use !gVncStarted for fast poll")

need(
    re.search(r"gLeaseFails\s*>=\s*2\s*&&\s*gVncStarted", server),
    "disconnect must still require gLeaseFails >= 2 && gVncStarted",
)

need(
    re.search(
        r"BOOL\s+TVLeasePendingPair\(void\)\s*\{.*?DeviceToken.*?return NO",
        lease,
        re.S,
    ),
    "TVLeasePendingPair must return NO when DeviceToken exists",
)

need("TVPairFailBanner" in lease and "20" in lease, "pair-fail banner must be debounced")

if errs:
    print("FAIL")
    for e in errs:
        print(" -", e)
    sys.exit(1)
print("ok: fast poll only while pending pair; disconnect budget unchanged (2x60s)")
sys.exit(0)
