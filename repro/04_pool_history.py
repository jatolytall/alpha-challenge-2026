#!/usr/bin/env python3
"""
Reproduces the core claim of challenge 04 from public data. No API keys.

Claim: the answer needs no candidate enumeration, because the Meteora DLMM pool
that TRUMP first traded on has exactly 15 transactions in its entire history
before the first snipe, and all of them belong to the launch team. The next
third-party transaction is therefore the answer by definition.

Only the official free Solana endpoint is used. It serves January 2025 from
long-term storage, so no paid indexer is required.
"""
import json
import sys
import urllib.request

RPC = "https://api.mainnet-beta.solana.com"

# Meteora DLMM pool, TRUMP/USDC — every launch trade went through it.
POOL = "A8nPhpCJqtqHdqUk35Uj9Hy2YsGXFkCZGuNwvkD3k7VC"

# The first attempt to snipe the token (the answer to part one).
FIRST_SNIPE = (
    "41h3CuLHamSdfsmgWC887eoyvrTiUcGjhLZpKMeqE9Rg9ZkP42C2gBr5PrQM9D25jRFwwQYPfBUJYCEUXC1qAxcv"
)

EXPECTED_COUNT = 15
EXPECTED_OLDEST_SLOT = 314590039  # InitializeCustomizablePermissionlessLbPair
EXPECTED_SNIPE_SLOT = 314658584


def rpc(method: str, params: list) -> dict:
    payload = json.dumps(
        {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    ).encode()
    req = urllib.request.Request(
        RPC, data=payload, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.load(resp)
    if "error" in body:
        raise RuntimeError(f"{method}: {body['error']}")
    return body["result"]


def main() -> int:
    print(f"pool: {POOL}")
    print(f"endpoint: {RPC}\n")

    # Everything the pool ever saw BEFORE the first snipe.
    history = rpc(
        "getSignaturesForAddress",
        [POOL, {"before": FIRST_SNIPE, "limit": 1000}],
    )

    print(f"transactions in pool history before the first snipe: {len(history)}\n")
    for entry in sorted(history, key=lambda e: e["slot"]):
        ts = entry.get("blockTime")
        when = (
            __import__("datetime")
            .datetime.utcfromtimestamp(ts)
            .strftime("%Y-%m-%d %H:%M:%S UTC")
            if ts
            else "?"
        )
        print(f"  slot {entry['slot']}  {when}  {entry['signature'][:24]}...")

    # The snipe itself, for the timeline.
    snipe = rpc("getTransaction", [FIRST_SNIPE, {"maxSupportedTransactionVersion": 0}])
    snipe_slot = snipe["slot"]
    print(f"\nfirst snipe: slot {snipe_slot}")

    oldest = min(e["slot"] for e in history)
    print(f"oldest pool transaction: slot {oldest}")

    ok = True
    if len(history) != EXPECTED_COUNT:
        print(
            f"\nMISMATCH: expected {EXPECTED_COUNT} transactions, got {len(history)}",
            file=sys.stderr,
        )
        ok = False
    if oldest != EXPECTED_OLDEST_SLOT:
        print(
            f"MISMATCH: expected oldest slot {EXPECTED_OLDEST_SLOT}, got {oldest}",
            file=sys.stderr,
        )
        ok = False
    if snipe_slot != EXPECTED_SNIPE_SLOT:
        print(
            f"MISMATCH: expected snipe slot {EXPECTED_SNIPE_SLOT}, got {snipe_slot}",
            file=sys.stderr,
        )
        ok = False

    if not ok:
        return 1

    print(
        f"\nOK: the pool's entire pre-snipe history is {EXPECTED_COUNT} launch-team "
        "transactions, so the next third-party transaction is the answer by "
        "definition — no candidate enumeration needed."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
